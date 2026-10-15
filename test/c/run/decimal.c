/* C23'S DECIMAL FLOATING TYPES (0.129): _Decimal32, _Decimal64, _Decimal128 -- read and sized since 0.93, refused by name
   until 0.129 (decimal_floating_type). A value is its BID encoding carried as a float, a double or an fp128 (the registers gcc
   passes it in); every operation is a call of libgcc's decimal runtime; a literal is encoded exactly from its text. gcc is the
   reference: clang has no decimal types. */
#include <stdio.h>

_Decimal64 g1 = 0.1dd;
_Decimal32 g2 = -2.5df;
_Decimal128 g3 = 7;
_Decimal64 g4[3] = { 1.5dd, -0.25dd, 1e3dd };
struct money { const char *what; _Decimal64 amount; _Decimal32 rate; };
struct money g5 = { "fee", 19.99dd, 0.05df };

static _Decimal64 add(_Decimal64 a, _Decimal64 b) { return a + b; }
static _Decimal128 scale(_Decimal128 a, int k) { return a * k; }
static _Decimal32 half(_Decimal32 x) { return x / 2; }
static int sign(_Decimal64 x) { return x < 0 ? -1 : x > 0 ? 1 : 0; }
static double d(_Decimal64 x) { return (double)x; }

int main(void) {
  _Decimal64 a = 0.1dd, b = 0.2dd, c = add(a, b);
  printf("%d %d %d\n", c == 0.3dd, 0.1 + 0.2 == 0.3, (double)c == 0.3);
  printf("%.17g %.17g %.17g\n", d(g1), (double)g2, (double)g3);
  printf("%g %g %g\n", d(g4[0]), d(g4[1]), d(g4[2]));
  printf("%s %.4f %.4f\n", g5.what, d(g5.amount), (double)g5.rate);
  _Decimal64 x = 7.5dd;
  x += 2; x -= 0.5dd; x *= 3; x /= 4;
  printf("%g\n", d(x));
  _Decimal64 i = 0;
  for (int k = 0; k < 10; k++) i += 0.1dd;
  printf("%d %d\n", i == 1, i == 1.0dd);
  i++; ++i; i--;
  printf("%g %g\n", d(i), d(-i));
  printf("%d %d %d %d %d %d\n", a < b, a <= b, a > b, a >= b, a == b, a != b);
  printf("%d %d %d\n", sign(-3.25dd), sign(0.0dd), sign(1e-5dd));
  printf("%d %d %d\n", !a, !(a - a), a && b);
  if (a) printf("a is true\n");
  _Decimal32 s = 1.25df;
  _Decimal128 t = 10.0dl;
  printf("%g %g %g\n", (double)(s * s), (double)(t / 4), (double)half(s));
  printf("%g %g\n", (double)(s + a), (double)(t - a));
  printf("%g\n", (double)scale(1.5dl, 4));
  long l = (long)(a * 1000);
  unsigned u = (unsigned)(b * 100);
  int n = (int)-2.75dd;
  short h = (short)12.9dd;
  _Bool z = 0.0dd, nz = 0.001dd;
  printf("%ld %u %d %d %d %d\n", l, u, n, h, (int)z, (int)nz);
  _Decimal64 fi = 42, fu = 4000000000u, fl = -9000000000L;
  _Decimal64 fd = 2.5, ff = 0.5f;
  long double ld = (long double)fd;
  _Decimal64 fld = (long double)1.25;
  printf("%g %g %g %g %g %Lg %g\n", d(fi), d(fu), d(fl), d(fd), d(ff), ld, d(fld));
  _Decimal32 n32 = 1.5dd;
  _Decimal128 w = n32;
  _Decimal64 back = w;
  printf("%g %g\n", (double)w, d(back));
  printf("%d\n", 0.12345678901234567890dd == 0.1234567890123457dd);
  printf("%d %d\n", 1.0dd == 1.00dd, .5dd == 0.5dd);
  printf("%d %d %d\n", (int)sizeof(_Decimal32), (int)sizeof(_Decimal64), (int)sizeof(_Decimal128));
  printf("%d %d\n", _Generic(1.0dd, _Decimal64: 1, default: 0), _Generic(a + s, _Decimal64: 2, default: 0));
  _Decimal64 m = a > b ? a : 3;
  printf("%g\n", d(m));
  return 0;
}
