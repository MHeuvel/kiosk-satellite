#include <cstdint>

namespace {
// Explicit wrapping matches Dart's Int16List stores and int32 coercions.
int16_t wrap16(int32_t value) {
    const uint32_t bits = static_cast<uint32_t>(value) & 65535u;
    return static_cast<int16_t>(static_cast<int32_t>(bits) -
                               ((bits & 32768u) ? 65536 : 0));
}

int32_t sround(int64_t value) {
    const uint32_t bits = static_cast<uint32_t>(value + 16384);
    return static_cast<int32_t>(bits >> 15) -
           ((bits & 0x80000000u) ? 131072 : 0);
}

int32_t div2(int32_t value) { return sround(int64_t{value} * 16383); }
int32_t div4(int32_t value) { return sround(int64_t{value} * 8191); }
int32_t realProduct(int32_t r, int32_t i, int32_t cr, int32_t ci) {
    return sround(int64_t{r} * cr - int64_t{i} * ci);
}
int32_t imagProduct(int32_t r, int32_t i, int32_t cr, int32_t ci) {
    return sround(int64_t{r} * ci + int64_t{i} * cr);
}

// The frontend always uses a 512-point real transform. Its 256-point complex
// plan consists of four radix-4 stages. Read packed real input directly.
void work(int16_t* r, int16_t* im, int offset, const int16_t* input,
          int source, int stride, int m, const int16_t* cosine,
          const int16_t* sine) {
    for (int k = 0; k < 4; ++k) {
        if (m == 1) {
            r[offset + k] = input[2 * (source + k * stride)];
            im[offset + k] = input[2 * (source + k * stride) + 1];
        } else {
            work(r, im, offset + k * m, input, source + k * stride,
                 stride * 4, m / 4, cosine, sine);
        }
    }
    for (int k = 0; k < m; ++k) {
        const int p0 = offset + k, p1 = p0 + m;
        const int p2 = p1 + m, p3 = p2 + m;
        r[p0] = wrap16(div4(r[p0])); im[p0] = wrap16(div4(im[p0]));
        r[p1] = wrap16(div4(r[p1])); im[p1] = wrap16(div4(im[p1]));
        r[p2] = wrap16(div4(r[p2])); im[p2] = wrap16(div4(im[p2]));
        r[p3] = wrap16(div4(r[p3])); im[p3] = wrap16(div4(im[p3]));
        const int t1 = stride * k, t2 = 2 * t1, t3 = 3 * t1;
        const int s0r = realProduct(r[p1], im[p1], cosine[t1], sine[t1]);
        const int s0i = imagProduct(r[p1], im[p1], cosine[t1], sine[t1]);
        const int s1r = realProduct(r[p2], im[p2], cosine[t2], sine[t2]);
        const int s1i = imagProduct(r[p2], im[p2], cosine[t2], sine[t2]);
        const int s2r = realProduct(r[p3], im[p3], cosine[t3], sine[t3]);
        const int s2i = imagProduct(r[p3], im[p3], cosine[t3], sine[t3]);
        const int s5r = r[p0] - s1r, s5i = im[p0] - s1i;
        r[p0] = wrap16(r[p0] + s1r); im[p0] = wrap16(im[p0] + s1i);
        const int s3r = s0r + s2r, s3i = s0i + s2i;
        const int s4r = s0r - s2r, s4i = s0i - s2i;
        r[p2] = wrap16(r[p0] - s3r); im[p2] = wrap16(im[p0] - s3i);
        r[p0] = wrap16(r[p0] + s3r); im[p0] = wrap16(im[p0] + s3i);
        r[p1] = wrap16(s5r + s4i); im[p1] = wrap16(s5i - s4r);
        r[p3] = wrap16(s5r - s4i); im[p3] = wrap16(s5i + s4r);
    }
}

// Arithmetic right shift without relying on signed-shift behavior.
int32_t half(int32_t value) {
    return value >= 0 ? value / 2 : -((-value + 1) / 2);
}
} // namespace

// io: 512 input samples followed by 257 real and 257 imaginary outputs.
// tables: 256 cosine, 256 sine, 128 real-twiddle cosine and 128 sine values.
// scratch: 256 real and 256 imaginary values. All storage belongs to Dart.
extern "C" __attribute__((visibility("default")))
void ks_mww_fft(int16_t* io, const int16_t* tables, int16_t* scratch) {
    auto* r = scratch;
    auto* im = scratch + 256;
    auto* outR = io + 512;
    auto* outI = outR + 257;
    work(r, im, 0, io, 0, 1, 64, tables, tables + 256);
    const int dcR = div2(r[0]), dcI = div2(im[0]);
    outR[0] = wrap16(dcR + dcI); outI[0] = 0;
    outR[256] = wrap16(dcR - dcI); outI[256] = 0;
    for (int k = 1; k <= 128; ++k) {
        const int fpkR = div2(r[k]), fpkI = div2(im[k]);
        const int fpnkR = div2(r[256 - k]), fpnkI = div2(-int32_t{im[256 - k]});
        const int f1r = fpkR + fpnkR, f1i = fpkI + fpnkI;
        const int f2r = fpkR - fpnkR, f2i = fpkI - fpnkI;
        const int cr = tables[512 + k - 1], ci = tables[640 + k - 1];
        const int tr = realProduct(f2r, f2i, cr, ci);
        const int ti = imagProduct(f2r, f2i, cr, ci);
        outR[k] = wrap16(half(f1r + tr));
        outI[k] = wrap16(half(f1i + ti));
        outR[256 - k] = wrap16(half(f1r - tr));
        outI[256 - k] = wrap16(half(ti - f1i));
    }
}
