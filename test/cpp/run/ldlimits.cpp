// A LONG DOUBLE LITERAL KEEPS ITS EXACT VALUE (0.154): libc++'s numeric_limits<long double> returns the long double
// headers' __LDBL_MAX__ and kin, which held a double's value (max() was the largest double, min() and denorm_min()
// zeros); a static constexpr member folds from the literal's exact value; a template deduces long double from `1.5L'
#include <cstdio>
#include <limits>
#include <cstring>

// a subnormal by its bits, exponent and significand: Apple's %La writes it normalized, glibc's not (0.250)
static const char *bits(long double v) {
    static char out[32];
    unsigned long long m; unsigned short e;
    std::memcpy(&m, &v, 8); std::memcpy(&e, (const char *) &v + 8, 2);
    std::snprintf(out, sizeof out, "%04x:%016llx", (unsigned) e, m);
    return out;
}

struct K {
    static constexpr long double tenth = 0.1L;
    static constexpr long double third = 1.0L / 3;
    static constexpr long double big = 1e4000L;
};

template <class T> int width(T) { return sizeof(T); }
template <class T> T half(T x) { return x / 2; }

int main() {
    using L = std::numeric_limits<long double>;
    std::printf("%La %La %La\n", L::max(), L::lowest(), L::min());
    std::printf("%s %La %La\n", bits(L::denorm_min()), L::epsilon(), L::round_error());
    std::printf("%d %d %d %d\n", L::digits, L::max_exponent, L::min_exponent, L::has_denorm);
    std::printf("%La %La %La\n", K::tenth, K::third, K::big);
    std::printf("%d %La\n", width(1.5L), half(0x1.0000000000000002p0L));
    long double x = 1e-4940L, y = 0.3L;
    std::printf("%s %La %d\n", bits(x), y, y == 0.3);
    return 0;
}
