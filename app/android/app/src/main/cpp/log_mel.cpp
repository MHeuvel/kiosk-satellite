#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>

// vsWakeWord log-mel frames, computed straight from the audio ring the plan
// owns (the isolate writes into a view of it) into feature rows it also owns.
// Same operations in the same order as LogMelExtractor's Dart path: float32
// samples and coefficients widened to double, the shared radix-2 FFT, double
// power and mel sums, natural log rounded to float32. Keep contraction and fast
// math disabled or the features stop matching the Dart and JS references.

extern "C" void ks_wake_fft(int32_t n, double* re, double* im,
                            const double* cosine, const double* sine,
                            const uint32_t* reverse);

namespace {
struct Plan {
    int32_t windowSamples, frameLen, hop, nFft, frames, mels, halfBins;
    double logFloor;
    float* ring;           // windowSamples
    float* features;       // frames * mels
    float* window;         // frameLen
    int32_t* lo;           // mels
    int32_t* hi;           // mels
    int32_t* coeffStart;   // mels
    float* coeffs;         // sum of (hi - lo)
    double* cosine;        // nFft
    double* sine;          // nFft
    uint32_t* reverse;     // nFft
    double* re;            // nFft
    double* im;            // nFft
    double* power;         // halfBins
};
}  // namespace

// Tables are copied, so the caller's buffers may go away after this returns.
extern "C" __attribute__((visibility("default")))
void* ks_vsww_create(int32_t windowSamples, int32_t frameLen, int32_t hop,
                     int32_t nFft, int32_t frames, int32_t mels,
                     double logFloor,
                     const float* window, const int32_t* lo,
                     const int32_t* hi, const float* coeffs,
                     const double* cosine, const double* sine,
                     const uint32_t* reverse) {
    auto* p = static_cast<Plan*>(std::calloc(1, sizeof(Plan)));
    if (p == nullptr) return nullptr;
    p->windowSamples = windowSamples;
    p->frameLen = frameLen;
    p->hop = hop;
    p->nFft = nFft;
    p->frames = frames;
    p->mels = mels;
    p->halfBins = nFft / 2 + 1;
    p->logFloor = logFloor;
    int32_t total = 0;
    for (int32_t m = 0; m < mels; ++m) total += hi[m] - lo[m];
    p->ring = static_cast<float*>(std::calloc(windowSamples, sizeof(float)));
    p->features =
        static_cast<float*>(std::calloc(frames * mels, sizeof(float)));
    p->window = static_cast<float*>(std::malloc(sizeof(float) * frameLen));
    p->lo = static_cast<int32_t*>(std::malloc(sizeof(int32_t) * mels));
    p->hi = static_cast<int32_t*>(std::malloc(sizeof(int32_t) * mels));
    p->coeffStart = static_cast<int32_t*>(std::malloc(sizeof(int32_t) * mels));
    p->coeffs = static_cast<float*>(std::malloc(sizeof(float) * (total + 1)));
    p->cosine = static_cast<double*>(std::malloc(sizeof(double) * nFft));
    p->sine = static_cast<double*>(std::malloc(sizeof(double) * nFft));
    p->reverse = static_cast<uint32_t*>(std::malloc(sizeof(uint32_t) * nFft));
    p->re = static_cast<double*>(std::malloc(sizeof(double) * nFft));
    p->im = static_cast<double*>(std::malloc(sizeof(double) * nFft));
    p->power = static_cast<double*>(std::malloc(sizeof(double) * p->halfBins));
    if (!p->ring || !p->features || !p->window || !p->lo || !p->hi ||
        !p->coeffStart || !p->coeffs || !p->cosine || !p->sine ||
        !p->reverse || !p->re || !p->im || !p->power) {
        std::free(p->ring); std::free(p->features);
        std::free(p->window); std::free(p->lo); std::free(p->hi);
        std::free(p->coeffStart); std::free(p->coeffs); std::free(p->cosine);
        std::free(p->sine); std::free(p->reverse); std::free(p->re);
        std::free(p->im); std::free(p->power); std::free(p);
        return nullptr;
    }
    std::memcpy(p->window, window, sizeof(float) * frameLen);
    std::memcpy(p->lo, lo, sizeof(int32_t) * mels);
    std::memcpy(p->hi, hi, sizeof(int32_t) * mels);
    std::memcpy(p->coeffs, coeffs, sizeof(float) * total);
    std::memcpy(p->cosine, cosine, sizeof(double) * nFft);
    std::memcpy(p->sine, sine, sizeof(double) * nFft);
    std::memcpy(p->reverse, reverse, sizeof(uint32_t) * nFft);
    int32_t start = 0;
    for (int32_t m = 0; m < mels; ++m) {
        p->coeffStart[m] = start;
        start += hi[m] - lo[m];
    }
    return p;
}

extern "C" __attribute__((visibility("default")))
void ks_vsww_free(void* plan) {
    auto* p = static_cast<Plan*>(plan);
    if (p == nullptr) return;
    std::free(p->ring); std::free(p->features);
    std::free(p->window); std::free(p->lo); std::free(p->hi);
    std::free(p->coeffStart); std::free(p->coeffs); std::free(p->cosine);
    std::free(p->sine); std::free(p->reverse); std::free(p->re);
    std::free(p->im); std::free(p->power); std::free(p);
}

extern "C" __attribute__((visibility("default")))
float* ks_vsww_ring(void* plan) { return static_cast<Plan*>(plan)->ring; }

extern "C" __attribute__((visibility("default")))
float* ks_vsww_features(void* plan) {
    return static_cast<Plan*>(plan)->features;
}

// Frames [first, frames) of the window that starts at ring[head] and wraps,
// written as float32 rows of `mels` into the features. Earlier rows are left
// alone: the caller has already shifted them into place.
extern "C" __attribute__((visibility("default")))
void ks_vsww_frames(void* plan, int32_t head, int32_t first) {
    auto* p = static_cast<Plan*>(plan);
    const float* ring = p->ring;
    const int32_t n = p->windowSamples;
    for (int32_t f = first; f < p->frames; ++f) {
        int32_t idx = head + f * p->hop;
        if (idx >= n) idx %= n;
        for (int32_t i = 0; i < p->frameLen; ++i) {
            p->re[i] = static_cast<double>(ring[idx]) *
                       static_cast<double>(p->window[i]);
            if (++idx == n) idx = 0;
        }
        for (int32_t i = p->frameLen; i < p->nFft; ++i) p->re[i] = 0.0;
        for (int32_t i = 0; i < p->nFft; ++i) p->im[i] = 0.0;
        ks_wake_fft(p->nFft, p->re, p->im, p->cosine, p->sine, p->reverse);
        for (int32_t k = 0; k < p->halfBins; ++k) {
            p->power[k] = p->re[k] * p->re[k] + p->im[k] * p->im[k];
        }
        float* row = p->features + f * p->mels;
        for (int32_t m = 0; m < p->mels; ++m) {
            const float* c = p->coeffs + p->coeffStart[m];
            const int32_t lo = p->lo[m];
            double energy = 0.0;
            for (int32_t k = lo; k < p->hi[m]; ++k) {
                energy += static_cast<double>(c[k - lo]) * p->power[k];
            }
            const double v = energy > p->logFloor ? energy : p->logFloor;
            row[m] = static_cast<float>(std::log(v));
        }
    }
}

// Sum of squares over the window that starts at ring[head], in window order.
extern "C" __attribute__((visibility("default")))
double ks_vsww_sum_squares(void* plan, int32_t head) {
    const auto* p = static_cast<Plan*>(plan);
    const float* ring = p->ring;
    const int32_t n = p->windowSamples;
    double sum = 0.0;
    for (int32_t i = head; i < n; ++i) {
        const double s = ring[i];
        sum += s * s;
    }
    for (int32_t i = 0; i < head; ++i) {
        const double s = ring[i];
        sum += s * s;
    }
    return sum;
}
