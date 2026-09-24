#include <cstdint>
#include <utility>

// The Dart frontend supplies its own tables so both paths use identical
// coefficients and operation order. Keep contraction and fast math disabled.
extern "C" __attribute__((visibility("default")))
void ks_wake_fft(int32_t n, double* __restrict re, double* __restrict im,
                 const double* __restrict cosine,
                 const double* __restrict sine,
                 const uint32_t* __restrict reverse) {
    for (int32_t i = 0; i < n; ++i) {
        const auto j = reverse[i];
        if (j > static_cast<uint32_t>(i)) {
            std::swap(re[i], re[j]);
            std::swap(im[i], im[j]);
        }
    }
    for (int32_t size = 2; size <= n; size <<= 1) {
        const int32_t half = size >> 1;
        const int32_t step = n / size;
        for (int32_t i = 0; i < n; i += size) {
            int32_t k = 0;
            for (int32_t j = i; j < i + half; ++j) {
                const double cr = cosine[k];
                const double ci = sine[k];
                const int32_t l = j + half;
                const double xr = re[l] * cr - im[l] * ci;
                const double xi = re[l] * ci + im[l] * cr;
                re[l] = re[j] - xr;
                im[l] = im[j] - xi;
                re[j] += xr;
                im[j] += xi;
                k += step;
            }
        }
    }
}
