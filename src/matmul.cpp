#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <immintrin.h>
#include <malloc.h>

#define NOINLINE __declspec(noinline)

#ifndef PROGRAM_VARIANT
#define PROGRAM_VARIANT "unknown"
#endif

static double seconds_now() {
    using clock = std::chrono::steady_clock;
    return std::chrono::duration<double>(clock::now().time_since_epoch()).count();
}

static float* allocate_matrix(std::size_t count) {
    auto* data = static_cast<float*>(_aligned_malloc(count * sizeof(float), 64));
    if (data == nullptr) {
        std::fputs("Allocation failed\n", stderr);
        std::exit(EXIT_FAILURE);
    }
    return data;
}

static NOINLINE void initialize(float* a, float* b, std::size_t n) {
    for (std::size_t i = 0; i < n; ++i) {
        for (std::size_t j = 0; j < n; ++j) {
            a[i * n + j] = static_cast<float>((i * 17 + j * 13) % 101) / 101.0f;
            b[i * n + j] = static_cast<float>((i * 29 + j * 7) % 103) / 103.0f;
        }
    }
}

static NOINLINE void matmul_kernel(const float* __restrict a,
                                   const float* __restrict b,
                                   float* __restrict c,
                                   std::size_t n) {
    for (std::size_t i = 0; i < n; ++i) {
        float* c_row = c + i * n;
        for (std::size_t k = 0; k < n; ++k) {
            const float value = a[i * n + k];
            const float* b_row = b + k * n;
#ifdef USE_AVX2
            const __m256 va = _mm256_set1_ps(value);
            for (std::size_t j = 0; j < n; j += 8) {
                const __m256 vb = _mm256_load_ps(b_row + j);
                const __m256 vc = _mm256_load_ps(c_row + j);
                _mm256_store_ps(c_row + j, _mm256_fmadd_ps(va, vb, vc));
            }
#else
            for (std::size_t j = 0; j < n; ++j) {
                c_row[j] += value * b_row[j];
            }
#endif
        }
    }
}

static NOINLINE double checksum(const float* data, std::size_t count) {
    double result = 0.0;
    for (std::size_t i = 0; i < count; ++i) {
        result += data[i];
    }
    return result;
}

int main(int argc, char** argv) {
    const std::size_t n = argc > 1 ? std::strtoull(argv[1], nullptr, 10) : 768;
    const std::size_t repeats = argc > 2 ? std::strtoull(argv[2], nullptr, 10) : 6;
    if (n == 0 || repeats == 0 || n % 16 != 0) {
        std::fputs("Use a positive matrix size divisible by 16 and a positive repeat count\n", stderr);
        return EXIT_FAILURE;
    }

    const std::size_t count = n * n;
    const std::size_t bytes = count * sizeof(float);
    float* a = allocate_matrix(count);
    float* b = allocate_matrix(count);
    float* c = allocate_matrix(count);
    initialize(a, b, n);

    const double start = seconds_now();
    for (std::size_t run = 0; run < repeats; ++run) {
        std::memset(c, 0, bytes);
        matmul_kernel(a, b, c, n);
    }
    const double elapsed = seconds_now() - start;
    const double operations = 2.0 * n * n * n * repeats;

    std::printf("variant=%s n=%zu repeats=%zu kernel_seconds=%.9f gflops=%.6f checksum=%.9f\n",
                PROGRAM_VARIANT, n, repeats, elapsed, operations / elapsed / 1.0e9, checksum(c, count));

    _aligned_free(c);
    _aligned_free(b);
    _aligned_free(a);
    return EXIT_SUCCESS;
}

