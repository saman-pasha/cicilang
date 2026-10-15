/* a decimal global's constant that is an infinity or a NaN (0.137): a division by zero, an operation over an infinity, an
   overflow, their conversions between the decimal kinds and to a binary floating global, folded as gcc folds them
   (IEEE 754-2008 7.2, 7.3); the expectation is gcc's. */
#include <stdio.h>
#include <string.h>
double nv = (double) (0.0DD / 0.0DD), nw = -(double) (0.0DD / 0.0DD); float nf = (float) (0.0DF / 0.0DF);
_Decimal64 nz = -(0.0DD / 0.0DD), m0 = -7.0DD / (1.0DD / 0.0DD);
_Decimal64 a = 1.5DD / 0.0DD, b = -2.0DD / 0.DD, c = 0.0DD / 0.0DD, d = 1.0DD / 0.0DD + 3.0DD, e = (1.0DD / 0.0DD) - (1.0DD / 0.0DD),
  f = (1.0DD / 0.0DD) * 0.0DD, g = (1.0DD / 0.0DD) * -2.5DD, h = 7.25DD / (1.0DD / 0.0DD), i = (1.0DD / 0.0DD) / (1.0DD / 0.0DD),
  j = -(1.0DD / 0.0DD), k = 1e400DD * 1e400DD, l = (_Decimal64) (1.0DL / 0.0DL), m = 0.00DD / 5.0DD, n = 1e-300DD / (1.0DD/0.0DD), o = (_Decimal64) (1.0DF / 0.0DF);
_Decimal32 p = 3.0DF / 0.0DF, q = (_Decimal32) (1.0DD/0.0DD), r = (_Decimal32) 1e200DD;
_Decimal128 s = 1.0DL / 0.0DL, t = 0.0DL / 0.0DL, u = (_Decimal128) (1.0DF / 0.0DF);
double v = (double) (1.0DD / 0.0DD); float w = (float) (-1.0DF / 0.0DF);
int main(void) {
  _Decimal64 xs[] = { a, b, c, d, e, f, g, h, i, j, k, l, m, n, o };
  for (unsigned z = 0; z < sizeof xs / sizeof xs[0]; z++) { unsigned long x; memcpy(&x, &xs[z], 8); printf("%c %016lx\n", 'a' + z, x); }
  unsigned y; memcpy(&y, &p, 4); printf("p %08x\n", y); memcpy(&y, &q, 4); printf("q %08x\n", y); memcpy(&y, &r, 4); printf("r %08x\n", y);
  unsigned long h2[2]; memcpy(h2, &s, 16); printf("s %016lx%016lx\n", h2[1], h2[0]); memcpy(h2, &t, 16); printf("t %016lx%016lx\n", h2[1], h2[0]);
  memcpy(h2, &u, 16); printf("u %016lx%016lx\n", h2[1], h2[0]);
  printf("v %f w %f\n", v, w);
  unsigned long a8; memcpy(&a8, &nv, 8); printf("nv %016lx", a8); memcpy(&a8, &nw, 8); printf(" nw %016lx", a8); memcpy(&y, &nf, 4); printf(" nf %08x", y);
  memcpy(&a8, &nz, 8); printf(" nz %016lx", a8); memcpy(&a8, &m0, 8); printf(" m0 %016lx\n", a8);
  return 0;
}
