/* va_arg of a struct, a union and a complex (SysV x86-64): each eightbyte is read from the register save area of its
   own class while the registers last, and the whole value from the overflow area when they do not. */
#include <stdarg.h>
#include <stdio.h>

struct P { int a; int b; };
struct Q { double d; int i; };
struct R { char c[40]; };
struct M { long l; double d; };
struct F { float x, y, z; };
union U { long l; double d; };
struct T { char c; short s; int i; };

static void take(int n, ...) {
    va_list ap;
    va_start(ap, n);
    for (int i = 0; i < n; i++) {
        struct P p = va_arg(ap, struct P);
        struct Q q = va_arg(ap, struct Q);
        struct R r = va_arg(ap, struct R);
        struct M m = va_arg(ap, struct M);
        printf("%d %d %g %d %s %ld %g\n", p.a, p.b, q.d, q.i, r.c, m.l, m.d);
    }
    va_end(ap);
}
static void many(int n, ...) {          /* more register-class values than registers: the rest are in the overflow area */
    va_list ap;
    va_start(ap, n);
    long s = 0;
    for (int i = 0; i < n; i++) { struct P p = va_arg(ap, struct P); s = s * 10 + p.a + p.b; }
    printf("%ld\n", s);
    va_end(ap);
}
static void floats(int n, ...) {
    va_list ap;
    va_start(ap, n);
    double s = 0;
    for (int i = 0; i < n; i++) {
        struct F f = va_arg(ap, struct F);
        union U u = va_arg(ap, union U);
        double _Complex z = va_arg(ap, double _Complex);
        struct T t = va_arg(ap, struct T);
        s += f.x + f.y * 2 + f.z * 3 + u.d + __real__ z + __imag__ z * 10 + t.c + t.s + t.i;
    }
    printf("%g\n", s);
    va_end(ap);
}
int main(void) {
    struct P p = {1, 2};
    struct Q q = {2.5, 3};
    struct R r = {"forty"};
    struct M m = {9, 1.5};
    take(2, p, q, r, m, p, q, r, m);
    many(9, p, p, p, p, p, p, p, p, p);
    struct F f = {1, 2, 3};
    union U u; u.d = 0.5;
    double _Complex z = 3.0 + 4.0 * 1.0i;
    struct T t = {1, 2, 3};
    floats(3, f, u, z, t, f, u, z, t, f, u, z, t);
    return 0;
}
