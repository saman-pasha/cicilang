// the twin of numbers.c over std::, built by clang++ over libc++: what the program prints
#include <cstdio>
#include <climits>
#include <cmath>
#include <ratio>
#include <random>
#include <complex>
#include <limits>
#include <charconv>
#include <vector>
#include <algorithm>
#include <system_error>

static void show(const char *what, char *b, std::to_chars_result r) {
    *r.ptr = 0;
    std::printf("%s %s %d\n", what, b, (int)(r.ec == std::errc()));
}

int main() {
    using a = std::ratio_add<std::ratio<1, 2>, std::ratio<1, 3>>;
    using m = std::ratio_multiply<std::ratio<1, 2>, std::ratio<1, 3>>;
    using s = std::ratio_subtract<std::ratio<1, 3>, std::ratio<1, 2>>;
    using d = std::ratio_divide<std::ratio<-3, 4>, std::ratio<9, 8>>;
    using q = std::ratio<-6, -8>;
    using big = std::ratio<4611686018427387904LL, 3>;
    using bm = std::ratio_multiply<std::ratio<4611686018427387904LL, 3>, std::ratio<3, 2>>;
    std::printf("ratio %lld/%lld %lld/%lld %lld/%lld %lld/%lld %lld/%lld %lld/%lld %lld/%lld\n", (long long)a::num,
                (long long)a::den, (long long)m::num, (long long)m::den, (long long)s::num, (long long)s::den,
                (long long)d::num, (long long)d::den, (long long)q::num, (long long)q::den, (long long)big::num,
                (long long)big::den, (long long)bm::num, (long long)bm::den);

    std::mt19937 r0;
    unsigned d0 = r0();
    unsigned d1 = r0();
    std::printf("default %u %u\n", d0, d1);
    std::mt19937 r(7);
    int neg = 0, lo = 0, hi = 0;
    std::uniform_int_distribution<int> five(-5, 5);
    for (int i = 0; i < 1000; i++) {
        int v = five(r);
        if (v < 0) neg++;
        if (v == -5) lo++;
        if (v == 5) hi++;
    }
    std::printf("uniform %d %d %d\n", neg, lo, hi);
    int w = std::uniform_int_distribution<int>(INT_MIN, INT_MAX)(r);
    unsigned u = std::uniform_int_distribution<unsigned>(0u, 4294967295u)(r);
    long long ll = std::uniform_int_distribution<long long>(-3000000000LL, 9000000000LL)(r);
    long long lw = std::uniform_int_distribution<long long>(LLONG_MIN, LLONG_MAX)(r);
    std::printf("whole %d %u %lld %lld\n", w, u, ll, lw);
    double ur = std::uniform_real_distribution<double>(-2.5, 7.0)(r);
    float uf = std::uniform_real_distribution<float>(0.0f, 1.0f)(r);
    long double ul = std::uniform_real_distribution<long double>(1.0L, 2.0L)(r);
    std::printf("real %.6f %.6f %.6Lf\n", ur, (double)uf, ul);
    int b1 = std::bernoulli_distribution(0.3)(r);
    int b2 = std::bernoulli_distribution(0.3)(r);
    int b3 = std::bernoulli_distribution(0.9)(r);
    std::printf("bernoulli %d %d %d\n", b1, b2, b3);
    std::vector<int> v = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    std::shuffle(v.begin(), v.end(), r);
    std::printf("shuffle");
    for (int x : v) std::printf(" %d", x);
    std::printf("\n");

    std::complex<double> h1(1e300, 1e300), h2(1e300, 1e300), hq = h1 / h2;
    std::complex<double> n1(1, 2), z0(0, 0), iq = n1 / z0;
    std::complex<double> ii(INFINITY, INFINITY), r1(1, 0), pi = ii * r1;
    std::complex<double> sq = std::sqrt(std::complex<double>(-4, 0));
    std::printf("complex %.17g %.17g, %.17g %.17g, %.17g %.17g, %.17g %.17g\n", hq.real(), hq.imag(), iq.real(), iq.imag(),
                pi.real(), pi.imag(), sq.real(), sq.imag());
    std::complex<double> one(1, 1), p2 = std::pow(one, 2.0), cz = std::cos(z0), sz = std::sin(one), tn = std::tan(one);
    std::printf("complex %.17g %.17g, %.17g %.17g, %.17g %.17g, %.17g %.17g\n", p2.real(), p2.imag(), cz.real(), cz.imag(),
                sz.real(), sz.imag(), tn.real(), tn.imag());
    std::complex<double> ni(INFINITY, NAN);
    std::printf("norm %g\n", std::norm(ni));
    std::complex<double> si(INFINITY, 0), ws = std::sin(si), ti(0, INFINITY), wt = std::tan(ti), wx = std::exp(std::complex<double>(NAN, 0));
    std::complex<double> qi(-INFINITY, 1), wq = std::sqrt(qi);
    std::printf("special %g %g, %g %g, %g %g, %g %g\n", ws.real(), ws.imag(), wt.real(), wt.imag(), wx.real(), wx.imag(),
                wq.real(), wq.imag());
    std::complex<float> fe = std::exp(std::complex<float>(0.5f, 0.25f));
    std::complex<long double> ls = std::sqrt(std::complex<long double>(2.0L, -1.0L));
    std::printf("complex float %.9g %.9g long double %.21Lg %.21Lg\n", (double)fe.real(), (double)fe.imag(), ls.real(), ls.imag());

    std::printf("limits %d %d %d %d\n", (int)std::numeric_limits<bool>::max(), std::numeric_limits<bool>::digits,
                (int)std::numeric_limits<bool>::is_signed, std::numeric_limits<long double>::digits);

    char b[400];
    std::to_chars_result t;
    t = std::to_chars(b, b + 400, 0.1); show("plain", b, t);
    t = std::to_chars(b, b + 400, 0.0001); show("plain", b, t);
    t = std::to_chars(b, b + 400, 0.0001, std::chars_format::general); show("general", b, t);
    t = std::to_chars(b, b + 400, 12345678.9, std::chars_format::general); show("general", b, t);
    t = std::to_chars(b, b + 400, 0.1234567, std::chars_format::fixed); show("fixed", b, t);
    t = std::to_chars(b, b + 400, 1e-7, std::chars_format::fixed); show("fixed", b, t);
    t = std::to_chars(b, b + 400, 1e23, std::chars_format::fixed); show("fixed", b, t);
    t = std::to_chars(b, b + 400, 12345678.9, std::chars_format::scientific); show("sci", b, t);
    t = std::to_chars(b, b + 400, std::ldexp(1.0, -1017), std::chars_format::scientific); show("sci", b, t);
    t = std::to_chars(b, b + 400, 5e-324, std::chars_format::hex); show("hex", b, t);
    t = std::to_chars(b, b + 400, 0.1f); show("float", b, t);
    t = std::to_chars(b, b + 400, 3.14159, std::chars_format::fixed, 2); show("prec", b, t);
    t = std::to_chars(b, b + 400, 12345678.9, std::chars_format::scientific, 3); show("prec", b, t);
    t = std::to_chars(b, b + 400, 0.000123456, std::chars_format::general, 4); show("prec", b, t);
    t = std::to_chars(b, b + 400, -NAN); show("nan", b, t);
    t = std::to_chars(b, b + 400, -INFINITY, std::chars_format::fixed); show("inf", b, t);
    std::to_chars_result e1 = std::to_chars(b, b + 4, 123456.0);
    std::to_chars_result e2 = std::to_chars(b, b + 2, 12345);
    std::printf("small %d %d %d %d\n", (int)(e1.ptr - b), (int)(e1.ec == std::errc::value_too_large), (int)(e2.ptr - b), (int)(e2.ec == std::errc::value_too_large));

    double x = 7;
    const char *c;
    std::from_chars_result f;
    c = "1.8p1"; f = std::from_chars(c, c + 5, x, std::chars_format::hex);
    std::printf("from hex %d %d %g\n", (int)(f.ptr - c), (int)(f.ec == std::errc()), x);
    x = 7; c = "ff.8"; f = std::from_chars(c, c + 4, x, std::chars_format::hex);
    std::printf("from hex digits %d %d %g\n", (int)(f.ptr - c), (int)(f.ec == std::errc()), x);
    x = 7; c = "0x10"; f = std::from_chars(c, c + 4, x);
    std::printf("from 0x %d %d %g\n", (int)(f.ptr - c), (int)(f.ec == std::errc()), x);
    x = 7; c = "1e5"; f = std::from_chars(c, c + 3, x, std::chars_format::fixed);
    std::printf("from fixed %d %d %g\n", (int)(f.ptr - c), (int)(f.ec == std::errc()), x);
    x = 7; c = "1"; f = std::from_chars(c, c + 1, x, std::chars_format::scientific);
    std::printf("from sci %d %d %g\n", (int)(f.ptr - c), (int)(f.ec == std::errc::invalid_argument), x);
    x = 7; c = " 1"; f = std::from_chars(c, c + 2, x);
    std::printf("from space %d %d %g\n", (int)(f.ptr - c), (int)(f.ec == std::errc::invalid_argument), x);
    x = 7; c = "1e-310"; f = std::from_chars(c, c + 6, x);
    std::printf("from denormal %d %d %g\n", (int)(f.ptr - c), (int)(f.ec == std::errc()), x);
    x = 7; c = "1e999"; f = std::from_chars(c, c + 5, x);
    std::printf("from range %d %d\n", (int)(f.ptr - c), (int)(f.ec == std::errc::result_out_of_range));
    float fl = 0;
    c = "1.000000178813934326171874999"; f = std::from_chars(c, c + 29, fl);
    std::printf("from float %d %d %.9g\n", (int)(f.ptr - c), (int)(f.ec == std::errc()), (double)fl);
    return 0;
}
