// A user-defined floating literal hands its literal operator the long double of its text (0.160), as clang++ does: it was
// the double nearest the text, widened -- 0.1_v was 0.100000000000000005551 and 1e999_v an infinity
#include <cstdio>

long double operator"" _v(long double x) { return x; }
double operator"" _half(long double x) { return (double) (x / 2); }
struct Len { long double m; };
Len operator"" _km(long double x) { return Len{x * 1000}; }

int main() {
    std::printf("%.21Lg %.21Lg %.21Lg\n", 0.1_v, 1.5_v, .5_v);
    std::printf("%Lg %.21Lg %.21Lg\n", 1e999_v, 0x1p-2_v, 1'000.25_v);
    std::printf("%.17g %.17g\n", 3.0_half, 1e3_half);
    std::printf("%.21Lg %.21Lg\n", (2.5_km).m, (0.001_km).m);
    return 0;
}
