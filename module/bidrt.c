/* bidrt.c: a decimal floating value to and from a 128-bit integer, the conversions libgcc does not have
   (__bid_floattidd, __bid_fixddti and kin; gcc's own link fails on them). Compiled by cicilang itself into
   library/ccl_bidrt.pl (module/gen-bidrt.sh), whose functions the lowering puts into a module, internal, where a
   conversion asks one (ccl_ir.pl, ir_dec_convert). Never edited in the generated file.
   To a decimal: the integer's magnitude rounded ONCE, half to even, to the kind's digits in integer arithmetic, then
   built from a 64-bit integer's exact conversion and exact multiplications by ten. From a decimal: its BID coefficient
   and exponent decoded, the coefficient scaled toward zero (a value past the integer's range has no defined result). */
typedef unsigned __int128 ccl_u128;
#define CCL_DEC_FROM(NAME, T, PMAX)                                                                 \
static T NAME(ccl_u128 u, int neg) {                                                                \
  int k = 0; unsigned rd = 0, sticky = 0;                                                           \
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
_Decimal32 __ccl_bid_floattisd(__int128 x) { return x < 0 ? __ccl_bid_u128_sd(-(ccl_u128) x, 1) : __ccl_bid_u128_sd((ccl_u128) x, 0); }
_Decimal64 __ccl_bid_floattidd(__int128 x) { return x < 0 ? __ccl_bid_u128_dd(-(ccl_u128) x, 1) : __ccl_bid_u128_dd((ccl_u128) x, 0); }
_Decimal128 __ccl_bid_floattitd(__int128 x) { return x < 0 ? __ccl_bid_u128_td(-(ccl_u128) x, 1) : __ccl_bid_u128_td((ccl_u128) x, 0); }
_Decimal32 __ccl_bid_floatunstisd(ccl_u128 x) { return __ccl_bid_u128_sd(x, 0); }
_Decimal64 __ccl_bid_floatunstidd(ccl_u128 x) { return __ccl_bid_u128_dd(x, 0); }
_Decimal128 __ccl_bid_floatunstitd(ccl_u128 x) { return __ccl_bid_u128_td(x, 0); }
static ccl_u128 __ccl_bid_scale(ccl_u128 c, int e) {
  if (e >= 0) { while (e-- > 0) c *= 10; return c; }
  if (e < -39) return 0;
  while (e++ < 0) c /= 10;
  return c;
}
static ccl_u128 __ccl_bid_sd_u128(_Decimal32 d, int *neg) {
  union { _Decimal32 d; unsigned b; } w; w.d = d; unsigned b = w.b; *neg = (int) (b >> 31); unsigned c; int e;
  if (((b >> 29) & 3) == 3) { e = (int) ((b >> 21) & 0xff); c = (b & 0x1fffff) | 0x800000; } else { e = (int) ((b >> 23) & 0xff); c = b & 0x7fffff; }
  return __ccl_bid_scale(c, e - 101);
}
static ccl_u128 __ccl_bid_dd_u128(_Decimal64 d, int *neg) {
  union { _Decimal64 d; unsigned long b; } w; w.d = d; unsigned long b = w.b; *neg = (int) (b >> 63); unsigned long c; int e;
  if (((b >> 61) & 3) == 3) { e = (int) ((b >> 51) & 0x3ff); c = (b & 0x7ffffffffffffull) | 0x20000000000000ull; } else { e = (int) ((b >> 53) & 0x3ff); c = b & 0x1fffffffffffffull; }
  return __ccl_bid_scale(c, e - 398);
}
static ccl_u128 __ccl_bid_td_u128(_Decimal128 d, int *neg) {
  union { _Decimal128 d; ccl_u128 b; } w; w.d = d; ccl_u128 b = w.b; *neg = (int) (b >> 127); ccl_u128 c; int e;
  if (((b >> 125) & 3) == 3) { e = (int) ((b >> 111) & 0x3fff); c = (b & (((ccl_u128) 1 << 111) - 1)) | ((ccl_u128) 1 << 113); } else { e = (int) ((b >> 113) & 0x3fff); c = b & (((ccl_u128) 1 << 113) - 1); }
  return __ccl_bid_scale(c, e - 6176);
}
__int128 __ccl_bid_fixsdti(_Decimal32 d) { int n; ccl_u128 u = __ccl_bid_sd_u128(d, &n); return n ? -(__int128) u : (__int128) u; }
__int128 __ccl_bid_fixddti(_Decimal64 d) { int n; ccl_u128 u = __ccl_bid_dd_u128(d, &n); return n ? -(__int128) u : (__int128) u; }
__int128 __ccl_bid_fixtdti(_Decimal128 d) { int n; ccl_u128 u = __ccl_bid_td_u128(d, &n); return n ? -(__int128) u : (__int128) u; }
ccl_u128 __ccl_bid_fixunssdti(_Decimal32 d) { int n; return __ccl_bid_sd_u128(d, &n); }
ccl_u128 __ccl_bid_fixunsddti(_Decimal64 d) { int n; return __ccl_bid_dd_u128(d, &n); }
ccl_u128 __ccl_bid_fixunstdti(_Decimal128 d) { int n; return __ccl_bid_td_u128(d, &n); }
