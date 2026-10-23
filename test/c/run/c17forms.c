/* C17 and C11 forms: _Generic with qualified types, _Noreturn, _Alignas, anonymous structs and unions, a flexible array
   member, a VLA parameter, static array parameter, a compound literal as an lvalue, designated initializers of nested
   arrays, wide characters, _Complex, the restrict qualifier, inline with external definition, __func__ */
#include <stdio.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <string.h>
struct F { int n; double d[]; };
struct A { union { int i; float f; }; struct { short lo, hi; }; };
int vla(int n, int a[n][n]) { int s = 0; for (int i = 0; i < n; i++) s += a[i][i]; return s; }
int st(int a[static 2]) { return a[0] + a[1]; }
inline int twice(int x) { return x * 2; }
extern inline int twice(int x);
noreturn void die(void) { exit(0); }
#define kind(x) _Generic((x), int: "int", const int *: "cip", int *: "ip", default: "other")
int main(void) {
    struct F *f = malloc(sizeof *f + 3 * sizeof(double)); f->n = 3; f->d[2] = 2.5;
    struct A a = { .i = 1, .lo = 2, .hi = 3 };
    int m[2][2] = { [0][0] = 1, [1][1] = 4 };
    const int c = 1; int x = 2;
    (int){ 5 } = 6;
    int *restrict rp = &x;
    printf("%.1f %d %d %d %d %d %s %s %s %d\n", f->d[2], a.i, a.lo, a.hi, vla(2, m), st((int[]){ 3, 4 }), kind(&c), kind(&x), kind(1.0), twice(*rp));
    free(f);
    die();
}
