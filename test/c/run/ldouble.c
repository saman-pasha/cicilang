/* long double as the x87's 80 bits on x86-64 (0.108): layout, arithmetic, calls, the ABI, globals, libm and complex */
#include <stdio.h>
#include <math.h>
#include <float.h>
#include <complex.h>
long double ld = 3.5L;
struct S { char c; long double x; };
struct LD { long double v; int tag; };
struct One { long double v; };
static long double half(long double x) { return x / 2; }
static struct LD mk(long double v) { struct LD s = { v, 7 }; return s; }
static long double sum(struct LD a, struct LD b) { return a.v + b.v; }
static long double twice(long double (*f)(long double), long double x) { return f(f(x)); }
static struct One inc(struct One o) { o.v += 1; return o; }
static long double get(struct One o) { return o.v; }
long double table[3] = { 1.25L, 2.5, 3 };
int main(void) {
    long double a = 1.0L / 3;
    printf("%zu %zu %zu %zu\n", sizeof(1.0L), sizeof(long double), sizeof(struct S), _Alignof(long double));
    printf("%.3Lf %.20Lf %.1Lf\n", ld, a, a * 3 + ld);
    long double x = 10;
    x = half(x) + 0.25L;
    printf("%.4Lf\n", x);
    struct LD p = mk(1.5L), q = mk(2.25L);
    printf("%.3Lf %d\n", sum(p, q), p.tag);
    printf("%.4Lf %.10Lf\n", twice(half, 12.0L), sqrtl(2.0L));
    printf("%d %d %d\n", (int)x, x > 5.0, x == 5.25L);
    double d = (double)(x * 2); float f = (float)x; long long ll = (long long)(x * 1000);
    printf("%.2f %.2f %lld\n", d, f, ll);
    printf("%.2Lf %.2Lf %.2Lf %d %d\n", table[0], table[1], table[2], LDBL_MANT_DIG, (int)sizeof(struct LD));
    long double acc = 0; for (int i = 1; i <= 10; i++) acc += 1.0L / i; printf("%.15Lf %Lg %Lg\n", acc, -x, x * x);
    struct One o = { 2.5L };
    o = inc(inc(o));
    printf("%.2Lf %.2Lf\n", o.v, get(o));
    long double _Complex z = 1.5L + 2.0L * I;
    long double _Complex w = z * z, r = w / z;
    printf("%.2Lf %.2Lf %.4Lf %.2Lf %.2Lf %zu\n", creall(w), cimagl(w), cabsl(z), creall(r), cimagl(r), sizeof r);
    long double inf = __builtin_infl(), nan = __builtin_nanl(""), zero = 0;
    printf("%d %d %d %d %d %d\n", isnan(nan), isinf(inf), isinf(-inf), isfinite(a), signbit(-a) != 0, isnormal(a));
    if (!zero) a++;
    _Bool b = a;
    printf("%.2Lf %d\n", a, b);
    return 0;
}
