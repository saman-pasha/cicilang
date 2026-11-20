/* ccllib 1.6.4 (CCLLIB.md's phases 1c and 2): the numbers as C++'s -- each ratio operation an instance of its own, a
   negative number, num and den as intmax_t; the engine's default seed, uniform_int over a negative range, a type's
   whole range and 64 bits, uniform_real of each floating type, bernoulli and shuffle, each by libc++'s algorithm; complex
   values by libc++'s formulas and the runtime's Annex G product and quotient; numeric_limits of a bool; to_chars's
   shortest texts in each form, at a precision, its NaN's words and its errors; from_chars by its format. Built by cicilang
   as C and by cicilang++ as C++, and compared with numbers.cpp over std::, which clang++ builds. */
#include <stdio.h>
#include <stdbool.h>
#include <limits.h>
#include <math.h>
#include <vector.pl>
#include <ratio.pl>
#include <random.pl>
#include <complex.pl>
#include <limits.pl>
#include <charconv.pl>

static void show(const char *what, char *b, to_chars_result r) {
    b[r.pos] = 0;
    printf("%s %s %d\n", what, b, r.ec == 0);
}

int main(void) {
    ratio_add<1, 2, 1, 3> a;
    ratio_multiply<1, 2, 1, 3> m;
    ratio_subtract<1, 3, 1, 2> s;
    ratio_divide<-3, 4, 9, 8> d;
    ratio<-6, -8> q;
    ratio<4611686018427387904, 3> big;
    ratio_multiply<4611686018427387904, 3, 3, 2> bm;
    printf("ratio %lld/%lld %lld/%lld %lld/%lld %lld/%lld %lld/%lld %lld/%lld %lld/%lld\n", num(a), den(a), num(m),
           den(m), num(s), den(s), num(d), den(d), num(q), den(q), num(big), den(big), num(bm), den(bm));

    mt19937<> r0;
    unsigned d0 = next(r0);
    unsigned d1 = next(r0);
    printf("default %u %u\n", d0, d1);
    mt19937<> r;
    seed(r, 7);
    int neg = 0, lo = 0, hi = 0;
    for (int i = 0; i < 1000; i++) {
        int v = uniform_int(r, -5, 5);
        if (v < 0) neg++;
        if (v == -5) lo++;
        if (v == 5) hi++;
    }
    printf("uniform %d %d %d\n", neg, lo, hi);
    int w = uniform_int(r, INT_MIN, INT_MAX);
    unsigned u = uniform_int(r, 0u, 4294967295u);
    long long ll = uniform_int(r, -3000000000LL, 9000000000LL);
    long long lw = uniform_int(r, LLONG_MIN, LLONG_MAX);
    printf("whole %d %u %lld %lld\n", w, u, ll, lw);
    double ur = uniform_real(r, -2.5, 7.0);
    float uf = uniform_real(r, 0.0f, 1.0f);
    long double ul = uniform_real(r, 1.0L, 2.0L);
    printf("real %.6f %.6f %.6Lf\n", ur, (double)uf, ul);
    int b1 = bernoulli(r, 0.3);
    int b2 = bernoulli(r, 0.3);
    int b3 = bernoulli(r, 0.9);
    printf("bernoulli %d %d %d\n", b1, b2, b3);
    vector<int> v = [int; 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    shuffle(v, r);
    printf("shuffle");
    for (size_t i = 0; i < size(v); i++) printf(" %d", at(v, i));
    printf("\n");

    complex<double> h1 = { 1e300, 1e300 };
    complex<double> h2 = { 1e300, 1e300 };
    complex<double> hq = h1 / h2;
    complex<double> n1 = { 1, 2 };
    complex<double> z0 = { 0, 0 };
    complex<double> iq = n1 / z0;
    complex<double> ii = { INFINITY, INFINITY };
    complex<double> r1 = { 1, 0 };
    complex<double> pi = ii * r1;
    complex<double> m4 = { -4, 0 };
    complex<double> sq = sqrt(m4);
    printf("complex %.17g %.17g, %.17g %.17g, %.17g %.17g, %.17g %.17g\n", real(hq), imag(hq), real(iq), imag(iq),
           real(pi), imag(pi), real(sq), imag(sq));
    complex<double> one = { 1, 1 };
    complex<double> p2 = pow(one, 2.0);
    complex<double> cz = cos(z0);
    complex<double> sz = sin(one);
    complex<double> tn = tan(one);
    printf("complex %.17g %.17g, %.17g %.17g, %.17g %.17g, %.17g %.17g\n", real(p2), imag(p2), real(cz), imag(cz),
           real(sz), imag(sz), real(tn), imag(tn));
    complex<double> ni = { INFINITY, NAN };
    printf("norm %g\n", norm(ni));
    complex<double> si = { INFINITY, 0 };
    complex<double> ws = sin(si);
    complex<double> ti = { 0, INFINITY };
    complex<double> wt = tan(ti);
    complex<double> ni0 = { NAN, 0 };
    complex<double> wx = exp(ni0);
    complex<double> qi = { -INFINITY, 1 };
    complex<double> wq = sqrt(qi);
    printf("special %g %g, %g %g, %g %g, %g %g\n", real(ws), imag(ws), real(wt), imag(wt), real(wx), imag(wx), real(wq),
           imag(wq));
    complex<float> fz = { 0.5f, 0.25f };
    complex<float> fe = exp(fz);
    complex<long double> lz = { 2.0L, -1.0L };
    complex<long double> ls = sqrt(lz);
    printf("complex float %.9g %.9g long double %.21Lg %.21Lg\n", (double)real(fe), (double)imag(fe), real(ls), imag(ls));

    numeric_limits<bool> nb;
    numeric_limits<long double> nl;
    printf("limits %d %d %d %d\n", (int)max(nb), digits(nb), is_signed(nb), digits(nl));

    char b[400];
    to_chars_result t;
    t = to_chars(b, b + 400, 0.1); show("plain", b, t);
    t = to_chars(b, b + 400, 0.0001); show("plain", b, t);
    t = to_chars(b, b + 400, 0.0001, chars_general); show("general", b, t);
    t = to_chars(b, b + 400, 12345678.9, chars_general); show("general", b, t);
    t = to_chars(b, b + 400, 0.1234567, chars_fixed); show("fixed", b, t);
    t = to_chars(b, b + 400, 1e-7, chars_fixed); show("fixed", b, t);
    t = to_chars(b, b + 400, 1e23, chars_fixed); show("fixed", b, t);
    t = to_chars(b, b + 400, 12345678.9, chars_scientific); show("sci", b, t);
    t = to_chars(b, b + 400, ldexp(1.0, -1017), chars_scientific); show("sci", b, t);
    t = to_chars(b, b + 400, 5e-324, chars_hex); show("hex", b, t);
    t = to_chars(b, b + 400, 0.1f); show("float", b, t);
    t = to_chars(b, b + 400, 3.14159, chars_fixed, 2); show("prec", b, t);
    t = to_chars(b, b + 400, 12345678.9, chars_scientific, 3); show("prec", b, t);
    t = to_chars(b, b + 400, 0.000123456, chars_general, 4); show("prec", b, t);
    t = to_chars(b, b + 400, -NAN); show("nan", b, t);
    t = to_chars(b, b + 400, -INFINITY, chars_fixed); show("inf", b, t);
    to_chars_result e1 = to_chars(b, b + 4, 123456.0);
    to_chars_result e2 = to_chars(b, b + 2, 12345);
    printf("small %d %d %d %d\n", (int)e1.pos, e1.ec == ccllib_errc_value_too_large, (int)e2.pos, e2.ec == ccllib_errc_value_too_large);

    double x = 7;
    from_chars_result f;
    f = from_chars("1.8p1", "1.8p1" + 5, x, chars_hex);
    printf("from hex %d %d %g\n", (int)f.pos, f.ec == 0, x);
    x = 7; f = from_chars("ff.8", "ff.8" + 4, x, chars_hex);
    printf("from hex digits %d %d %g\n", (int)f.pos, f.ec == 0, x);
    x = 7; f = from_chars("0x10", "0x10" + 4, x);
    printf("from 0x %d %d %g\n", (int)f.pos, f.ec == 0, x);
    x = 7; f = from_chars("1e5", "1e5" + 3, x, chars_fixed);
    printf("from fixed %d %d %g\n", (int)f.pos, f.ec == 0, x);
    x = 7; f = from_chars("1", "1" + 1, x, chars_scientific);
    printf("from sci %d %d %g\n", (int)f.pos, f.ec == ccllib_errc_invalid_argument, x);
    x = 7; f = from_chars(" 1", " 1" + 2, x);
    printf("from space %d %d %g\n", (int)f.pos, f.ec == ccllib_errc_invalid_argument, x);
    x = 7; f = from_chars("1e-310", "1e-310" + 6, x);
    printf("from denormal %d %d %g\n", (int)f.pos, f.ec == 0, x);
    x = 7; f = from_chars("1e999", "1e999" + 5, x);
    printf("from range %d %d\n", (int)f.pos, f.ec == ccllib_errc_result_out_of_range);
    float fl = 0;
    f = from_chars("1.000000178813934326171874999", "1.000000178813934326171874999" + 29, fl);
    printf("from float %d %d %.9g\n", (int)f.pos, f.ec == 0, (double)fl);
    return 0;
}
