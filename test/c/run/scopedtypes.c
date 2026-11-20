/* scopedtypes.c (1.6.2): a type that a block's object or a block's typedef gives is that block's, as clang reads it --
   __typeof__ of a name that two blocks declare with two types, as a local's type, an array's element, a pointer's
   target and sizeof's operand; a typedef name that two blocks give two types; a file-scope typedef after a function
   whose block gives its name another type, read again after a block that gives it a third; a block's typedef of a
   typeof, taken where the typedef stands */
#include <stdio.h>
static void f(void) { typedef double T; T x = 2.5; printf("%g ", x); }
typedef int T;
static int g(void) { T y = 7; return y; }
int main(void) {
    int r1 = ({ int a = 7; __typeof__(a) t = a; t; });
    long r2 = ({ long a = 5000000000L; __typeof__(a) t = a; t; });
    { int b = 1; __typeof__(b) u = b; printf("%d ", u); }
    { double b = 2.5; __typeof__(b) u = b; printf("%g ", u); }
    printf("%d %ld\n", r1, r2);
    { typedef int U; U a = 1; printf("%d ", a); }
    { typedef double U; U b = 2.5; printf("%g ", b); }
    { struct S { int x; } s = { 3 }; printf("%d ", s.x); }
    { struct S { double y; long z; } t = { 4.5, 6 }; printf("%g %ld ", t.y, t.z); }
    { int b = 1; printf("%zu ", sizeof(__typeof__(b))); }
    { double b = 2.5; printf("%zu ", sizeof(__typeof__(b))); }
    { int c = 1; __typeof__(c) arr[2] = { c, c }; printf("%d ", arr[1]); }
    { double c = 2.5; __typeof__(c) arr[2] = { c, c }; printf("%g ", arr[1]); }
    { int d = 1; __typeof__(d) *p = &d; printf("%d ", *p); }
    { double d = 2.5; __typeof__(d) *p = &d; printf("%g\n", *p); }
    f();
    T z = 3;
    { typedef char *T; T s = "abc"; printf("%s ", s); { T t = s + 1; printf("%s ", t); } }
    T w = 4;
    __typeof__(w) w2 = 5;
    _Static_assert(sizeof(T) == sizeof(int), "T is the file's typedef again");
    printf("%d %d %d %d %zu\n", g(), z, w, w2, sizeof(T));
    { double m = 1.5; typedef __typeof__(m) M; { int m = 2; M v = m; printf("%g %d %zu\n", v, m, sizeof(M)); } }
    return 0;
}
