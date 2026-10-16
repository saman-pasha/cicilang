/* A LONG DOUBLE CONSTANT CONVERTED TO A DECIMAL TYPE folds as gcc folds it (0.154): from the long double's exact value, then
   gcc's steps (57 digits, the trailing zeros cropped, a _Decimal128 of them, the type's digits, each rounded half to even);
   it was refused, decimal_constant(E), while a long double literal held a double's value. The driver gate compares the bits
   of cicilang's build with gcc's (clang has no decimal types) */
#include <stdio.h>
#include <float.h>

_Decimal64 a = 0.1L;
_Decimal128 b = 0.1L;
_Decimal32 c = 1.5L;
_Decimal128 d = LDBL_MAX;
_Decimal128 e = LDBL_MIN;
_Decimal64 f = -2.5L;
_Decimal128 g = 1.0L / 3.0L;
_Decimal128 h = 0x1.8p-3L;
_Decimal64 i = LDBL_TRUE_MIN;
_Decimal32 j = 1e999L;
_Decimal128 k = 3.14159265358979323846264338327950288419716939937510L;
_Decimal64 l = (long double) 9007199254740993;

static void pr(const char *n, const void *p, int k) {
    const unsigned char *x = p;
    printf("%s ", n);
    for (int m = k - 1; m >= 0; m--) printf("%02x", x[m]);
    printf("\n");
}

int main(void) {
    pr("a", &a, 8); pr("b", &b, 16); pr("c", &c, 4); pr("d", &d, 16); pr("e", &e, 16); pr("f", &f, 8);
    pr("g", &g, 16); pr("h", &h, 16); pr("i", &i, 8); pr("j", &j, 4); pr("k", &k, 16); pr("l", &l, 8);
    return 0;
}
