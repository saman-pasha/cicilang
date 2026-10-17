/* a decimal floating value to and from a _BitInt past 128 bits (0.160): libgcc 13 has no such routine, so cicilang puts its
   own (module/bidrt.c) into the module. No gcc here reads _BitInt: the expectation is Python's decimal module, exactly. */
#include <stdio.h>
#include <string.h>
typedef _BitInt(200) b200;
typedef unsigned _BitInt(256) u256;
static void pbig(u256 u) { for (int i = 3; i >= 0; i--) printf("%016lx", (unsigned long) (u >> (64 * i))); }
static _Decimal32 b_sd(b200 x) { return (_Decimal32) x; }
static _Decimal64 b_dd(b200 x) { return x; }
static _Decimal128 b_td(b200 x) { return (_Decimal128) x; }
static _Decimal128 u_td(u256 x) { return (_Decimal128) x; }
static b200 td_b(_Decimal128 d) { return (b200) d; }
static b200 dd_b(_Decimal64 d) { return d; }
static u256 td_u(_Decimal128 d) { return (u256) d; }
int main(void) {
  b200 e18 = 1000000000000000000LL, p150 = (b200) 1 << 150;
  b200 xs[] = { 0, 1, -1, p150, -p150 + 7, e18 * e18 * e18 * 100000, (e18 * e18 * 1000000000000000LL + 5) * 10,
    e18 * e18 * 100000000000000LL + 5, e18 * e18 * 100000000000000LL + 15, (b200) 123456789012345678LL * e18 * e18 + 987654321,
    -((b200) 1 << 198) * 2, ((b200) 1 << 198) - 1 + ((b200) 1 << 198), (b200) 99999995 * e18 * e18,
    (b200) 12345675 * e18 * e18 * 10000000000000000LL };   /* every value in the range of a _BitInt(200), whose largest is 2^199 - 1, some 8.03e59 */
  for (unsigned i = 0; i < sizeof xs / sizeof xs[0]; i++) {
    _Decimal32 s = b_sd(xs[i]); _Decimal64 d = b_dd(xs[i]); _Decimal128 t = b_td(xs[i]);
    unsigned sh; unsigned long dh, th[2]; memcpy(&sh, &s, 4); memcpy(&dh, &d, 8); memcpy(th, &t, 16);
    printf("%08x %016lx %016lx%016lx ", sh, dh, th[1], th[0]);
    pbig((u256) td_b(t)); printf(" "); pbig((u256) dd_b(d)); printf("\n");
  }
  u256 top = ~(u256) 0; _Decimal128 ut = u_td(top); unsigned long uth[2]; memcpy(uth, &ut, 16);
  printf("%016lx%016lx ", uth[1], uth[0]); pbig(td_u(ut)); printf("\n");
  _Decimal128 ds[] = { 1.9DL, -1.9DL, 9.999999999999999999999999999999999E58DL, -1234567890123456789012345678901234E25DL, 1E-30DL };
  for (unsigned i = 0; i < sizeof ds / sizeof ds[0]; i++) { pbig((u256) td_b(ds[i])); printf("\n"); }
  return 0;
}
