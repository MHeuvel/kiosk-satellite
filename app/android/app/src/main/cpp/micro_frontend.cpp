#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>

// microWakeWord's frontend after the PCM16 input: window, int16 real FFT,
// filterbank, noise reduction, PCAN gain and log scale. A port of
// MicroFrontend._processWindow, which must stay bit-exact with the JS
// reference the models were validated against. The Dart port does its
// integer math in doubles; every value there is an integer below 2^53, so the
// int64 arithmetic here gives the same numbers. Divisions by powers of two
// floor toward -infinity like the reference's Math.floor(a / b).
//
// Tables come from the Dart side, so there is one source for their values.

extern "C" void ks_mww_fft(int16_t* io, const int16_t* tables,
                           int16_t* scratch);

namespace {
constexpr int kWindowSize = 480;
constexpr int kStepSize = 160;
constexpr int kFftSize = 512;
constexpr int kSpectrumSize = 257;
constexpr int kFeatureSize = 40;
constexpr int kChannels = kFeatureSize + 1;
constexpr int kWindowBits = 12;
constexpr int kNoiseReductionBits = 14;
constexpr int kSmoothingBits = 10;
constexpr int kInputCorrectionBits = 3;
constexpr int kSnrShift = 6;
constexpr int kPcanSnrBits = 12;
constexpr int kPcanOutputBits = 6;
constexpr int kLogScaleLog2 = 16;
constexpr int kLogSegmentsLog2 = 7;
constexpr int64_t kLogCoeff = 45426;
constexpr int kGainLutSize = 4 * 32 + 4;
constexpr int kLogLutSize = (1 << kLogSegmentsLog2) + 2;
// Samples per feed call: one 80 ms chunk, at most 9 rows out.
constexpr int kBatch = 1280;
constexpr int kBatchRows = kBatch / kStepSize + 1;

struct State {
    int16_t window[kWindowSize];
    int16_t freqStarts[kChannels];
    int16_t weightStarts[kChannels];
    int16_t widths[kChannels];
    int16_t* weights;
    int16_t* unweights;
    int16_t fftTables[768];
    int16_t gainLut[kGainLutSize];
    int32_t logLut[kLogLutSize];
    int64_t evenSmoothing, oddSmoothing, minSignal;

    int16_t pcm[kBatch];                     // written by Dart
    float rows[kBatchRows * kFeatureSize];   // read by Dart
    int16_t input[kWindowSize];
    int32_t inputUsed;
    uint32_t noiseEstimate[kFeatureSize];

    // ks_mww_fft layout: 512 input samples, then 257 real and 257 imaginary.
    int16_t fftIo[kFftSize + 2 * kSpectrumSize];
    int16_t fftScratch[512];
    uint64_t work[kChannels];
    int64_t signal[kFeatureSize];
};

int32_t i32(int64_t v) {
    return static_cast<int32_t>(static_cast<uint32_t>(v));
}

int64_t floorDiv(int64_t a, int64_t b) {
    int64_t q = a / b;
    if ((a % b) != 0 && ((a < 0) != (b < 0))) --q;
    return q;
}

int msb32(uint32_t v) { return v == 0 ? 0 : 32 - __builtin_clz(v); }

int64_t wideDynamic(uint32_t x, const int16_t* lut) {
    if (x <= 2) return lut[x];
    const int interval = msb32(x);
    const int offset = 4 * interval - 6;
    const uint32_t frac =
        (interval < 11 ? static_cast<uint32_t>(x << (11 - interval))
                       : (x >> (interval - 11))) &
        0x3ff;
    int64_t result = floorDiv(int64_t{lut[offset + 2]} * frac, 32);
    result += int64_t{lut[offset + 1]} * 32;
    result *= frac;
    result = floorDiv(result + (1 << 14), 1 << 15);
    result += lut[offset];
    return result;
}

int64_t pcanShrink(int64_t x) {
    if (x < (2 << kPcanSnrBits)) {
        return floorDiv(x * x, int64_t{1} << (2 + 2 * kPcanSnrBits -
                                              kPcanOutputBits));
    }
    return floorDiv(x, 1 << (kPcanSnrBits - kPcanOutputBits)) -
           (1 << kPcanOutputBits);
}

int64_t logScale(int64_t value, const int32_t* logLut) {
    const uint32_t x = static_cast<uint32_t>(value);
    const int integer = msb32(x) - 1;
    // log2 fraction part
    int64_t frac = i32(int64_t{x} - (int64_t{1} << integer));
    if (integer < kLogScaleLog2) {
        frac = i32(frac << (kLogScaleLog2 - integer));
    } else {
        frac = static_cast<uint32_t>(frac) >> (integer - kLogScaleLog2);
    }
    const uint32_t baseSeg =
        static_cast<uint32_t>(frac) >> (kLogScaleLog2 - kLogSegmentsLog2);
    const int64_t segUnit = (1 << kLogScaleLog2) >> kLogSegmentsLog2;
    const int64_t c0 = logLut[baseSeg];
    const int64_t c1 = logLut[baseSeg + 1];
    const int64_t relPos =
        floorDiv((c1 - c0) * (frac - segUnit * baseSeg), 1 << kLogScaleLog2);
    const int64_t fraction = frac + c0 + relPos;

    const int64_t log2 = i32(int64_t{integer} << kLogScaleLog2) + fraction;
    const int64_t round = (1 << kLogScaleLog2) / 2;
    const int64_t loge =
        floorDiv(kLogCoeff * log2 + round, 1 << kLogScaleLog2);
    return floorDiv(i32(loge << 6) + round, 1 << kLogScaleLog2);
}

void processWindow(State* s, float* out) {
    int32_t maxAbs = 0;
    int16_t* fftTime = s->fftIo;
    for (int i = 0; i < kWindowSize; ++i) {
        const int32_t value =
            (int32_t{s->input[i]} * s->window[i]) >> kWindowBits;
        fftTime[i] = static_cast<int16_t>(value);
        const int32_t a = value < 0 ? -value : value;
        if (a > maxAbs) maxAbs = a;
    }
    int shift = 15 - msb32(static_cast<uint32_t>(maxAbs));
    if (shift < 0) shift = 0;
    for (int i = 0; i < kWindowSize; ++i) {
        const uint32_t u = static_cast<uint16_t>(fftTime[i]);
        fftTime[i] = static_cast<int16_t>(static_cast<uint16_t>(u << shift));
    }
    for (int i = kWindowSize; i < kFftSize; ++i) fftTime[i] = 0;

    ks_mww_fft(s->fftIo, s->fftTables, s->fftScratch);
    const int16_t* re = s->fftIo + kFftSize;
    const int16_t* im = re + kSpectrumSize;

    // Weights are checked non-negative at create, so 32 x 32 -> 64 bit
    // unsigned multiply-accumulates cover them.
    uint64_t weightAcc = 0, unweightAcc = 0;
    for (int ch = 0; ch < kChannels; ++ch) {
        const int freqStart = s->freqStarts[ch];
        const int weightStart = s->weightStarts[ch];
        const int width = s->widths[ch];
        for (int j = 0; j < width; ++j) {
            const int bin = freqStart + j;
            const int32_t r = re[bin], m = im[bin];
            const uint32_t mag = static_cast<uint32_t>(r * r) +
                                 static_cast<uint32_t>(m * m);
            weightAcc += uint64_t{static_cast<uint32_t>(
                             s->weights[weightStart + j])} * mag;
            unweightAcc += uint64_t{static_cast<uint32_t>(
                               s->unweights[weightStart + j])} * mag;
        }
        s->work[ch] = weightAcc;
        weightAcc = unweightAcc;
        unweightAcc = 0;
    }

    for (int i = 0; i < kFeatureSize; ++i) {
        // Dart: sqrt(sum).round(). The sums stay below 2^53, so both halves
        // convert exactly, and the root below 2^32 truncates as its floor.
        const uint64_t sum = s->work[i + 1];
        const double value =
            static_cast<double>(static_cast<uint32_t>(sum >> 32)) *
                4294967296.0 +
            static_cast<double>(static_cast<uint32_t>(sum));
        const double root = std::sqrt(value);
        const uint32_t floor = static_cast<uint32_t>(root);
        const uint32_t rounded =
            root - static_cast<double>(floor) >= 0.5 ? floor + 1 : floor;
        s->signal[i] = rounded >> shift;
    }

    // Noise reduction
    const int64_t nrPow = int64_t{1} << kNoiseReductionBits;
    const int64_t smPow = int64_t{1} << kSmoothingBits;
    for (int i = 0; i < kFeatureSize; ++i) {
        const int64_t smoothing = (i & 1) == 0 ? s->evenSmoothing
                                               : s->oddSmoothing;
        const int64_t oneMinus = nrPow - smoothing;
        const uint32_t scaledUp =
            static_cast<uint32_t>(s->signal[i] * smPow);
        const int64_t estSum = int64_t{scaledUp} * smoothing +
                               int64_t{s->noiseEstimate[i]} * oneMinus;
        const uint32_t estimate =
            static_cast<uint32_t>(floorDiv(estSum, nrPow));
        s->noiseEstimate[i] = estimate;
        const uint32_t clamped = estimate > scaledUp ? scaledUp : estimate;
        const uint32_t floorVal = static_cast<uint32_t>(
            floorDiv(s->signal[i] * s->minSignal, nrPow));
        const uint32_t subtracted = static_cast<uint32_t>(
            floorDiv(int64_t{scaledUp} - clamped, smPow));
        s->signal[i] = subtracted > floorVal ? subtracted : floorVal;
    }

    // PCAN auto gain
    for (int i = 0; i < kFeatureSize; ++i) {
        const int64_t gain = wideDynamic(s->noiseEstimate[i], s->gainLut);
        const int64_t snr = floorDiv(s->signal[i] * gain, 1 << kSnrShift);
        s->signal[i] = pcanShrink(snr);
    }

    for (int i = 0; i < kFeatureSize; ++i) {
        const int64_t corrected = s->signal[i] * (1 << kInputCorrectionBits);
        const int64_t logged = corrected > 1 ? logScale(corrected, s->logLut)
                                             : 0;
        const int64_t clamped = logged < 0xFFFF ? logged : 0xFFFF;
        out[i] = static_cast<float>(static_cast<double>(clamped) * 0.0390625);
    }
}
}  // namespace

// Returns null when the tables do not fit the fixed 512-point layout.
extern "C" __attribute__((visibility("default")))
void* ks_mww_frontend_create(
    const int16_t* window, const int16_t* freqStarts,
    const int16_t* weightStarts, const int16_t* widths,
    const int16_t* weights, const int16_t* unweights, int32_t weightCount,
    const int16_t* fftTables, const int16_t* gainLut, int32_t gainLutSize,
    const int32_t* logLut, int32_t logLutSize, int32_t evenSmoothing,
    int32_t oddSmoothing, int32_t minSignal) {
    if (gainLutSize != kGainLutSize || logLutSize != kLogLutSize) {
        return nullptr;
    }
    for (int ch = 0; ch < kChannels; ++ch) {
        if (freqStarts[ch] < 0 || widths[ch] < 0 || weightStarts[ch] < 0 ||
            freqStarts[ch] + widths[ch] > kSpectrumSize ||
            weightStarts[ch] + widths[ch] > weightCount) {
            return nullptr;
        }
    }
    for (int i = 0; i < weightCount; ++i) {
        if (weights[i] < 0 || unweights[i] < 0) return nullptr;
    }
    auto* s = static_cast<State*>(std::calloc(1, sizeof(State)));
    if (s == nullptr) return nullptr;
    s->weights = static_cast<int16_t*>(
        std::malloc(sizeof(int16_t) * (weightCount + 1)));
    s->unweights = static_cast<int16_t*>(
        std::malloc(sizeof(int16_t) * (weightCount + 1)));
    if (s->weights == nullptr || s->unweights == nullptr) {
        std::free(s->weights);
        std::free(s->unweights);
        std::free(s);
        return nullptr;
    }
    std::memcpy(s->window, window, sizeof(s->window));
    std::memcpy(s->freqStarts, freqStarts, sizeof(s->freqStarts));
    std::memcpy(s->weightStarts, weightStarts, sizeof(s->weightStarts));
    std::memcpy(s->widths, widths, sizeof(s->widths));
    std::memcpy(s->weights, weights, sizeof(int16_t) * weightCount);
    std::memcpy(s->unweights, unweights, sizeof(int16_t) * weightCount);
    std::memcpy(s->fftTables, fftTables, sizeof(s->fftTables));
    std::memcpy(s->gainLut, gainLut, sizeof(s->gainLut));
    std::memcpy(s->logLut, logLut, sizeof(s->logLut));
    s->evenSmoothing = evenSmoothing;
    s->oddSmoothing = oddSmoothing;
    s->minSignal = minSignal;
    return s;
}

extern "C" __attribute__((visibility("default")))
void ks_mww_frontend_free(void* state) {
    auto* s = static_cast<State*>(state);
    if (s == nullptr) return;
    std::free(s->weights);
    std::free(s->unweights);
    std::free(s);
}

extern "C" __attribute__((visibility("default")))
void ks_mww_frontend_reset(void* state) {
    auto* s = static_cast<State*>(state);
    std::memset(s->input, 0, sizeof(s->input));
    std::memset(s->noiseEstimate, 0, sizeof(s->noiseEstimate));
    s->inputUsed = 0;
}

extern "C" __attribute__((visibility("default")))
int16_t* ks_mww_frontend_pcm(void* state) {
    return static_cast<State*>(state)->pcm;
}

extern "C" __attribute__((visibility("default")))
float* ks_mww_frontend_rows(void* state) {
    return static_cast<State*>(state)->rows;
}

extern "C" __attribute__((visibility("default")))
int32_t ks_mww_frontend_batch() { return kBatch; }

// Feeds the first `length` samples of the state's pcm buffer (at most
// kBatch) and writes one 40-feature row per completed 10 ms step into its
// rows buffer. Returns the number of rows.
extern "C" __attribute__((visibility("default")))
int32_t ks_mww_frontend_feed(void* state, int32_t length) {
    auto* s = static_cast<State*>(state);
    if (length > kBatch) length = kBatch;
    const int16_t* pcm = s->pcm;
    float* out = s->rows;
    int32_t frames = 0;
    int32_t offset = 0;
    while (offset < length) {
        int32_t writable = kWindowSize - s->inputUsed;
        if (writable > length - offset) writable = length - offset;
        std::memcpy(s->input + s->inputUsed, pcm + offset,
                    sizeof(int16_t) * writable);
        s->inputUsed += writable;
        offset += writable;
        if (s->inputUsed < kWindowSize) continue;
        processWindow(s, out + frames * kFeatureSize);
        ++frames;
        std::memmove(s->input, s->input + kStepSize,
                     sizeof(int16_t) * (kWindowSize - kStepSize));
        s->inputUsed -= kStepSize;
    }
    return frames;
}
