/* bidrt.c: a decimal floating value to and from a 128-bit integer, the conversions libgcc does not have
   (__bid_floattidd, __bid_fixddti and kin; gcc's own link fails on them). Compiled by cicilang itself into
   library/ccl_bidrt.pl (module/gen-bidrt.sh), whose functions the lowering puts into a module, internal, where a
   conversion asks one (ccl_ir.pl, ir_dec_convert). Never edited in the generated file.
   To a decimal: the integer's magnitude rounded ONCE, half to even, to the kind's digits in integer arithmetic, then
   built from a 64-bit integer's exact conversion and exact multiplications by ten. From a decimal: its BID coefficient
   and exponent decoded, the coefficient scaled toward zero (a value past the integer's range has no defined result). */
typedef unsigned __int128 ccl_u128;
#define CCL_DEC_FROM(NAME, T, PMAX)                                                                 \
static T NAME(ccl_u128 u, int neg, int k, unsigned rd, unsigned sticky) {                           \
  while (u >= (ccl_u128) (PMAX)) { sticky |= (rd != 0); rd = (unsigned) (u % 10); u /= 10; k++; } \
  if (rd > 5 || (rd == 5 && (sticky || (unsigned) (u & 1)))) { u++; if (u == (ccl_u128) (PMAX)) { u /= 10; k++; } } \
  T d;                                                                                              \
  if ((u >> 64) != 0) { unsigned long hi = (unsigned long) (u / 100000000000000000ull), lo = (unsigned long) (u % 100000000000000000ull); \
    d = (T) hi * (T) 100000000000000000ull + (T) lo; }                                              \
  else d = (T) (unsigned long) u;                                                                   \
  while (k-- > 0) d = d * (T) 10;                                                                   \
  return neg ? -d : d;                                                                              \
}
CCL_DEC_FROM(__ccl_bid_u128_sd, _Decimal32, 10000000ull)
CCL_DEC_FROM(__ccl_bid_u128_dd, _Decimal64, 10000000000000000ull)
CCL_DEC_FROM(__ccl_bid_u128_td, _Decimal128, (ccl_u128) 10000000000000000ull * (ccl_u128) 1000000000000000000ull)
_Decimal32 __ccl_bid_floattisd(__int128 x) { return x < 0 ? __ccl_bid_u128_sd(-(ccl_u128) x, 1, 0, 0, 0) : __ccl_bid_u128_sd((ccl_u128) x, 0, 0, 0, 0); }
_Decimal64 __ccl_bid_floattidd(__int128 x) { return x < 0 ? __ccl_bid_u128_dd(-(ccl_u128) x, 1, 0, 0, 0) : __ccl_bid_u128_dd((ccl_u128) x, 0, 0, 0, 0); }
_Decimal128 __ccl_bid_floattitd(__int128 x) { return x < 0 ? __ccl_bid_u128_td(-(ccl_u128) x, 1, 0, 0, 0) : __ccl_bid_u128_td((ccl_u128) x, 0, 0, 0, 0); }
_Decimal32 __ccl_bid_floatunstisd(ccl_u128 x) { return __ccl_bid_u128_sd(x, 0, 0, 0, 0); }
_Decimal64 __ccl_bid_floatunstidd(ccl_u128 x) { return __ccl_bid_u128_dd(x, 0, 0, 0, 0); }
_Decimal128 __ccl_bid_floatunstitd(ccl_u128 x) { return __ccl_bid_u128_td(x, 0, 0, 0, 0); }
static ccl_u128 __ccl_bid_scale(ccl_u128 c, int e) {
  if (e >= 0) { while (e-- > 0) c *= 10; return c; }
  if (e < -39) return 0;
  while (e++ < 0) c /= 10;
  return c;
}
static ccl_u128 __ccl_bid_sd_ce(_Decimal32 d, int *neg, int *ex) {
  union { _Decimal32 d; unsigned b; } w; w.d = d; unsigned b = w.b; *neg = (int) (b >> 31); unsigned c; int e;
  if (((b >> 29) & 3) == 3) { e = (int) ((b >> 21) & 0xff); c = (b & 0x1fffff) | 0x800000; } else { e = (int) ((b >> 23) & 0xff); c = b & 0x7fffff; }
  *ex = e - 101; return c;
}
static ccl_u128 __ccl_bid_sd_u128(_Decimal32 d, int *neg) { int e; ccl_u128 c = __ccl_bid_sd_ce(d, neg, &e); return __ccl_bid_scale(c, e); }
static ccl_u128 __ccl_bid_dd_ce(_Decimal64 d, int *neg, int *ex) {
  union { _Decimal64 d; unsigned long b; } w; w.d = d; unsigned long b = w.b; *neg = (int) (b >> 63); unsigned long c; int e;
  if (((b >> 61) & 3) == 3) { e = (int) ((b >> 51) & 0x3ff); c = (b & 0x7ffffffffffffull) | 0x20000000000000ull; } else { e = (int) ((b >> 53) & 0x3ff); c = b & 0x1fffffffffffffull; }
  *ex = e - 398; return c;
}
static ccl_u128 __ccl_bid_dd_u128(_Decimal64 d, int *neg) { int e; ccl_u128 c = __ccl_bid_dd_ce(d, neg, &e); return __ccl_bid_scale(c, e); }
static ccl_u128 __ccl_bid_td_ce(_Decimal128 d, int *neg, int *ex) {
  union { _Decimal128 d; ccl_u128 b; } w; w.d = d; ccl_u128 b = w.b; *neg = (int) (b >> 127); ccl_u128 c; int e;
  if (((b >> 125) & 3) == 3) { e = (int) ((b >> 111) & 0x3fff); c = (b & (((ccl_u128) 1 << 111) - 1)) | ((ccl_u128) 1 << 113); } else { e = (int) ((b >> 113) & 0x3fff); c = b & (((ccl_u128) 1 << 113) - 1); }
  *ex = e - 6176; return c;
}
static ccl_u128 __ccl_bid_td_u128(_Decimal128 d, int *neg) { int e; ccl_u128 c = __ccl_bid_td_ce(d, neg, &e); return __ccl_bid_scale(c, e); }
__int128 __ccl_bid_fixsdti(_Decimal32 d) { int n; ccl_u128 u = __ccl_bid_sd_u128(d, &n); return n ? -(__int128) u : (__int128) u; }
__int128 __ccl_bid_fixddti(_Decimal64 d) { int n; ccl_u128 u = __ccl_bid_dd_u128(d, &n); return n ? -(__int128) u : (__int128) u; }
__int128 __ccl_bid_fixtdti(_Decimal128 d) { int n; ccl_u128 u = __ccl_bid_td_u128(d, &n); return n ? -(__int128) u : (__int128) u; }
ccl_u128 __ccl_bid_fixunssdti(_Decimal32 d) { int n; return __ccl_bid_sd_u128(d, &n); }
ccl_u128 __ccl_bid_fixunsddti(_Decimal64 d) { int n; return __ccl_bid_dd_u128(d, &n); }
ccl_u128 __ccl_bid_fixunstdti(_Decimal128 d) { int n; return __ccl_bid_td_u128(d, &n); }
/* _BitInt(N) PAST 128 BITS (0.160): its limbs, 64 bits each, the least first, `prec' its width, negative for a signed one, as
   libgcc's own _BitInt conversions take them (libgcc 13 has none). To a decimal: the magnitude divided by ten while it passes
   128 bits, the digits taken off kept for the one rounding; from a decimal: the coefficient scaled into the limbs, toward zero,
   the bits past the width dropped. The bits past the width in the last limb are taken as the value's own extension. */
typedef unsigned long ccl_limb;
static int ccl_bi_limbs(int prec) { int b = prec < 0 ? -prec : prec; return (b + 63) / 64; }
static int ccl_bi_load(const ccl_limb *p, int prec, ccl_limb *m, int n) {
  int b = prec < 0 ? -prec : prec, neg = 0, i, top = b - 64 * (n - 1);
  for (i = 0; i < n; i++) m[i] = p[i];
  if (top < 64) { ccl_limb mask = ((ccl_limb) 1 << top) - 1;
    if (prec < 0 && ((m[n - 1] >> (top - 1)) & 1)) m[n - 1] |= ~mask; else m[n - 1] &= mask; }
  if (prec < 0 && (m[n - 1] >> 63)) { unsigned c = 1; neg = 1;
    for (i = 0; i < n; i++) { ccl_limb x = ~m[i] + c; c = (c && x == 0); m[i] = x; } }
  return neg;
}
static unsigned ccl_bi_div10(ccl_limb *m, int n) {
  ccl_u128 r = 0; int i;
  for (i = n - 1; i >= 0; i--) { ccl_u128 cur = (r << 64) | m[i]; m[i] = (ccl_limb) (cur / 10); r = cur % 10; }
  return (unsigned) r;
}
static int ccl_bi_wide(const ccl_limb *m, int n) { int i; for (i = 2; i < n; i++) if (m[i]) return 1; return 0; }
#define CCL_DEC_FROM_BI(NAME, T, U128)                                                              \
T NAME(const ccl_limb *p, int prec) {                                                               \
  int n = ccl_bi_limbs(prec), k = 0; unsigned rd = 0, sticky = 0; ccl_limb m[n];                   \
  int neg = ccl_bi_load(p, prec, m, n);                                                             \
  while (ccl_bi_wide(m, n)) { sticky |= (rd != 0); rd = ccl_bi_div10(m, n); k++; }                 \
  ccl_u128 u = (ccl_u128) m[0] | (n > 1 ? (ccl_u128) m[1] << 64 : 0);                              \
  return U128(u, neg, k, rd, sticky);                                                               \
}
CCL_DEC_FROM_BI(__ccl_bid_floatbitintsd, _Decimal32, __ccl_bid_u128_sd)
CCL_DEC_FROM_BI(__ccl_bid_floatbitintdd, _Decimal64, __ccl_bid_u128_dd)
CCL_DEC_FROM_BI(__ccl_bid_floatbitinttd, _Decimal128, __ccl_bid_u128_td)
static void ccl_bi_store(ccl_limb *r, int prec, ccl_u128 c, int e, int neg) {
  int n = ccl_bi_limbs(prec), i;
  for (i = 0; i < n; i++) r[i] = 0;
  while (e < 0 && c != 0) { c /= 10; e++; }
  r[0] = (ccl_limb) c; if (n > 1) r[1] = (ccl_limb) (c >> 64);
  while (c != 0 && e-- > 0) { ccl_u128 carry = 0;
    for (i = 0; i < n; i++) { ccl_u128 cur = (ccl_u128) r[i] * 10 + carry; r[i] = (ccl_limb) cur; carry = cur >> 64; } }
  if (neg) { unsigned c1 = 1; for (i = 0; i < n; i++) { ccl_limb x = ~r[i] + c1; c1 = (c1 && x == 0); r[i] = x; } }
}
void __ccl_bid_fixsdbitint(ccl_limb *r, int prec, _Decimal32 d) { int n, e; ccl_u128 c = __ccl_bid_sd_ce(d, &n, &e); ccl_bi_store(r, prec, c, e, n); }
void __ccl_bid_fixddbitint(ccl_limb *r, int prec, _Decimal64 d) { int n, e; ccl_u128 c = __ccl_bid_dd_ce(d, &n, &e); ccl_bi_store(r, prec, c, e, n); }
void __ccl_bid_fixtdbitint(ccl_limb *r, int prec, _Decimal128 d) { int n, e; ccl_u128 c = __ccl_bid_td_ce(d, &n, &e); ccl_bi_store(r, prec, c, e, n); }
