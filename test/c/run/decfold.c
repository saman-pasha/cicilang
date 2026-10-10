/* A decimal floating constant folded as gcc folds it (C23 6.3.1.4, 6.3.1.5, IEEE 754-2008): a global's initializer
   is computed at compile time -- the arithmetic of decimal constants, a binary floating constant converted to a
   decimal type and a decimal constant to a binary one, each rounded to its type -- and its bits are printed: the BID
   encoding of the decimal ones, %a of the binary ones; a long double from a decimal constant is compared with the
   conversion the program makes at run time (libgcc's), since its format is the machine's. */
#include <stdio.h>
#include <string.h>
_Decimal64 a = 1.1dd + 2.2dd;
_Decimal64 b = 1.0dd / 3;
_Decimal32 c = 1.5df * 4;
_Decimal128 d = 10.0dl / 4;
_Decimal64 e = (_Decimal32)1.23456789dd;
_Decimal64 f = 1e300dd * 1e300dd;
_Decimal64 g = -0.0dd + 0.0dd;
_Decimal64 h = 2.50dd * 4.0dd;
_Decimal64 i = 7.0dd - 0.25dd;
_Decimal32 j = 2.0df / 3.0df;
_Decimal128 k = 1.0dl / 7;
_Decimal64 l = 123456789012345678.dd + 1;
_Decimal64 m = 100.dd / 10.dd;
_Decimal64 n = 1.dd / 8;
_Decimal64 o = 0.1;
_Decimal32 p = 0.1f;
_Decimal128 q = 1.0 / 3;
_Decimal64 r = 1e300;
_Decimal32 s = 2.5;
_Decimal64 t = -1.5e-7;
_Decimal128 u = 0.1;
_Decimal64 v = 100.0;
_Decimal64 w = 0.0;
_Decimal32 x = 16777216.0f;
_Decimal64 y = (float) 0.1;
_Decimal32 z = 1e-30;
_Decimal64 n0 = -0.0;
_Decimal128 n1 = 5e-324;
_Decimal32 n2 = 1e39;
double g1 = 0.1dd;
float g2 = 1.5df;
double g3 = 1.dd / 3;
double g5 = 1e-310dd;
double g6 = 123456789012345678901234567890.dd;
double g7 = 9007199254740993.dl;
double g8 = 0.3dd;
float g9 = 0.1dl;
double g10 = -2.5e-3dd;
double g11 = 4.9406564584124654e-324dl;
double g12 = 1.7976931348623157e308dl;
double g13 = 1e309dd;
long double la = 0.1dd;
long double lb = -1.dl / 3;
long double lc = 1e-4940dl;
long double ld = 9.999999999999999999999999999999999e6144dl;
static void bits64(const char *s, _Decimal64 x) { unsigned long long u; memcpy(&u, &x, 8); printf("%s %016llx\n", s, u); }
static void bits32(const char *s, _Decimal32 x) { unsigned u; memcpy(&u, &x, 4); printf("%s %08x\n", s, u); }
static void bits128(const char *s, _Decimal128 x) { unsigned long long u[2]; memcpy(u, &x, 16); printf("%s %016llx%016llx\n", s, u[1], u[0]); }
int main(void) {
  bits64("a", a); bits64("b", b); bits32("c", c); bits128("d", d); bits64("e", e); bits64("f", f); bits64("g", g);
  bits64("h", h); bits64("i", i); bits32("j", j); bits128("k", k); bits64("l", l); bits64("m", m); bits64("n", n);
  bits64("o", o); bits32("p", p); bits128("q", q); bits64("r", r); bits32("s", s); bits64("t", t); bits128("u", u);
  bits64("v", v); bits64("w", w); bits32("x", x); bits64("y", y); bits32("z", z); bits64("n0", n0); bits128("n1", n1);
  bits32("n2", n2);
  printf("%a %a %a %a %a %a\n", g1, (double) g2, g3, g5, g6, g7);
  printf("%a %a %a %a %a %a\n", g8, (double) g9, g10, g11, g12, g13);
  volatile _Decimal64 va = 0.1dd; volatile _Decimal128 vb = -1.dl / 3, vc = 1e-4940dl, vd = 9.999999999999999999999999999999999e6144dl;
  printf("%d %d %d %d\n", la == (long double) va, lb == (long double) vb, lc == (long double) vc, ld == (long double) vd);
  return 0;
}
