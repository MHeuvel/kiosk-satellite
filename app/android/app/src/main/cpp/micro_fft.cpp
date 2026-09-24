#include <cstdint>

namespace {
// Everything here is modulo 2^32, which is what the reference's int32
// coercions amount to: the low 32 bits of a sum or product do not depend on
// the high bits of its operands, so 32-bit unsigned arithmetic gives the same
// bits as the reference's wider math without any 64-bit operations.

// Keep the low 16 bits, like Dart's Int16List stores.
int16_t wrap16(uint32_t value) {
    return static_cast<int16_t>(static_cast<uint16_t>(value));
}

// sround(x) = (x + (1 << 14)) >> 15 on the int32 view of x.
int32_t sround(uint32_t value) {
    return static_cast<int32_t>(value + 16384u) >> 15;
}

uint32_t u(int32_t value) { return static_cast<uint32_t>(value); }

int32_t div2(int32_t value) { return sround(u(value) * 16383u); }
int32_t div4(int32_t value) { return sround(u(value) * 8191u); }
int32_t realProduct(int32_t r, int32_t i, int32_t cr, int32_t ci) {
    return sround(u(r) * u(cr) - u(i) * u(ci));
}
int32_t imagProduct(int32_t r, int32_t i, int32_t cr, int32_t ci) {
    return sround(u(r) * u(ci) + u(i) * u(cr));
}

// The frontend always uses a 512-point real transform. Its 256-point complex
// plan consists of four radix-4 stages. Read packed real input directly.
void work(int16_t* __restrict r, int16_t* __restrict im, int offset,
          const int16_t* __restrict input, int source, int stride, int m,
          const int16_t* __restrict cosine, const int16_t* __restrict sine) {
    if (m == 1) {
        for (int k = 0; k < 4; ++k) {
            r[offset + k] = input[2 * (source + k * stride)];
            im[offset + k] = input[2 * (source + k * stride) + 1];
        }
    } else {
        for (int k = 0; k < 4; ++k) {
            work(r, im, offset + k * m, input, source + k * stride,
                 stride * 4, m / 4, cosine, sine);
        }
    }
    for (int k = 0; k < m; ++k) {
        const int p0 = offset + k, p1 = p0 + m;
        const int p2 = p1 + m, p3 = p2 + m;
        const int32_t r0 = wrap16(u(div4(r[p0])));
        const int32_t i0 = wrap16(u(div4(im[p0])));
        const int32_t r1 = wrap16(u(div4(r[p1])));
        const int32_t i1 = wrap16(u(div4(im[p1])));
        const int32_t r2 = wrap16(u(div4(r[p2])));
        const int32_t i2 = wrap16(u(div4(im[p2])));
        const int32_t r3 = wrap16(u(div4(r[p3])));
        const int32_t i3 = wrap16(u(div4(im[p3])));
        const int t1 = stride * k, t2 = 2 * t1, t3 = 3 * t1;
        const int32_t s0r = realProduct(r1, i1, cosine[t1], sine[t1]);
        const int32_t s0i = imagProduct(r1, i1, cosine[t1], sine[t1]);
        const int32_t s1r = realProduct(r2, i2, cosine[t2], sine[t2]);
        const int32_t s1i = imagProduct(r2, i2, cosine[t2], sine[t2]);
        const int32_t s2r = realProduct(r3, i3, cosine[t3], sine[t3]);
        const int32_t s2i = imagProduct(r3, i3, cosine[t3], sine[t3]);
        const int32_t s5r = r0 - s1r, s5i = i0 - s1i;
        const int32_t q0r = wrap16(u(r0 + s1r)), q0i = wrap16(u(i0 + s1i));
        const int32_t s3r = s0r + s2r, s3i = s0i + s2i;
        const int32_t s4r = s0r - s2r, s4i = s0i - s2i;
        r[p2] = wrap16(u(q0r - s3r)); im[p2] = wrap16(u(q0i - s3i));
        r[p0] = wrap16(u(q0r + s3r)); im[p0] = wrap16(u(q0i + s3i));
        r[p1] = wrap16(u(s5r + s4i)); im[p1] = wrap16(u(s5i - s4r));
        r[p3] = wrap16(u(s5r - s4i)); im[p3] = wrap16(u(s5i + s4r));
    }
}

// Arithmetic shift: floor(value / 2), as Dart's >> 1.
int32_t half(int32_t value) { return value >> 1; }
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
        // The reference negates as int16, so -32768 stays -32768.
        const int fpnkR = div2(r[256 - k]);
        const int fpnkI = div2(wrap16(u(-int32_t{im[256 - k]})));
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
