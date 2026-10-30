/* decrt.c: THE COMPILER'S DECIMAL RUNTIME AGAINST LIBGCC'S (0.243). Every routine of module/bidrt.c, as cicilang compiles it
   (`__ccl_bid_adddd3' ...), and libgcc's of the same name (`__bid_adddd3' ...) are given the same operands -- random ones of
   every class, ties of the rounding, the binary formats' whole exponent ranges -- and their answers compared bit for bit; a
   NaN's by its class and sign alone where its payload is libgcc's own plumbing (C reads none), and a value to a binary format
   from canonical encodings only (libgcc's conversion reads a non-canonical coefficient as it is, where IEEE 754 makes it a
   zero). gcc builds this file (it calls libgcc's routines; clang has no decimal types); the driver gate links it with
   bidrt.c as `cicilang -c' makes it, and prints its last line:
     cicilang -c -std=c23 -O1 module/bidrt.c -o bidrt.o && gcc -std=gnu2x -O1 -w decrt.c bidrt.o -o decrt && ./decrt 3000 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
typedef unsigned __int128 u128;
typedef unsigned long u64;

static u64 rs = 0x9e3779b97f4a7c15ull;
static u64 rnd(void) { rs ^= rs << 13; rs ^= rs >> 7; rs ^= rs << 17; return rs; }
static u128 rnd128(void) { return (u128) rnd() << 64 | rnd(); }
static int rint_(int n) { return (int) (rnd() % (u64) n); }

static int P[3] = {7, 16, 34}, BIAS[3] = {101, 398, 6176}, EMAX[3] = {90, 369, 6111}, W[3] = {32, 64, 128}, EB[3] = {8, 10, 14};
static u128 p10(int n) { u128 r = 1; while (n-- > 0) r *= 10; return r; }
static u128 mask(int n) { return n >= 128 ? ~(u128) 0 : ((u128) 1 << n) - 1; }
static u128 pack(int k, int neg, u128 c, int e) {
  int w = W[k], eb = EB[k]; u128 be = (u128) (e + BIAS[k]), s = neg ? (u128) 1 << (w - 1) : 0;
  if ((c >> (w - 1 - eb)) == 0) return s | (be << (w - 1 - eb)) | c;
  return s | ((u128) 3 << (w - 3)) | (be << (w - 3 - eb)) | (c & mask(w - 3 - eb));
}
/* a random decimal of kind k: kinds of input by a die */
static u128 rdec(int k, int near_e, int *e_out) {
  int r = rint_(100), p = P[k], neg = rint_(2), e, nd;
  u128 c;
  if (r < 6) return rnd128() & mask(W[k]);                       /* any bits */
  if (r < 9) return pack(k, neg, 0, rint_(EMAX[k] + BIAS[k] + 1) - BIAS[k]);   /* a zero */
  if (r < 11) return ((u128) 30 << (W[k] - 6)) | (neg ? (u128) 1 << (W[k] - 1) : 0) | (rint_(2) ? rnd128() & mask(W[k] - 6) : 0);   /* an infinity */
  if (r < 13) return ((u128) (rint_(2) ? 62 : 63) << (W[k] - 7)) | (neg ? (u128) 1 << (W[k] - 1) : 0) | (rnd128() & mask(W[k] - 4 - EB[k]) % (rint_(2) ? p10(p - 1) : mask(W[k] - 4 - EB[k]) + 1));   /* a NaN */
  nd = r < 40 ? p : 1 + rint_(p);
  c = (rnd128() % p10(nd));
  if (r < 50 && nd > 2) c = c / 1000 * 1000;                        /* zeros on the right */
  if (r < 55) c = p10(rint_(p + 1)) - (rint_(2) ? 1 : 0);          /* a power of ten, or one less */
  if (c >= p10(p)) c = p10(p) - 1;
  if (near_e != -100000 && rint_(4) != 0) e = near_e + rint_(2 * p + 7) - p - 3;
  else if (rint_(3) == 0) e = rint_(41) - 20;
  else if (rint_(2) == 0) e = rint_(EMAX[k] + BIAS[k] + 1) - BIAS[k];
  else e = rint_(2) ? EMAX[k] - rint_(p + 3) : -BIAS[k] + rint_(p + 3);
  if (e < -BIAS[k]) e = -BIAS[k];
  if (e > EMAX[k]) e = EMAX[k];
  if (e_out) *e_out = e;
  return pack(k, neg, c, e);
}
static int rdec_e;
static u128 rdec1(int k) { return rdec(k, -100000, &rdec_e); }
static int noncanon(int k, u128 b) {   /* a finite value whose coefficient passes the kind's digits */
  int w = W[k], eb = EB[k]; u128 c;
  if (((b >> (w - 6)) & 31) >= 30) return 0;
  if (((b >> (w - 3)) & 3) == 3) c = (b & mask(w - 3 - eb)) | ((u128) 4 << (w - 3 - eb)); else c = b & mask(w - 1 - eb);
  return c >= p10(P[k]);
}
static u128 rdec_canon(int k) { u128 b; do b = rdec1(k); while (noncanon(k, b)); return b; }

/* a random binary float of format f's bits: 0 float, 1 double, 2 x87 long double, 3 quad */
static int BP[4] = {24, 53, 64, 113}, BEX[4] = {8, 11, 15, 15}, BFR[4] = {23, 52, 64, 112}, BEMAX[4] = {127, 1023, 16383, 16383};
static u128 rbin(int f) {
  int r = rint_(100), neg = rint_(2), bias = BEMAX[f], ex;
  u128 s = neg ? (u128) 1 << (BFR[f] + BEX[f]) : 0, fr = rnd128() & mask(BFR[f]);
  if (f == 2) fr |= (u128) 1 << 63;
  if (r < 10) { ex = rint_((int) mask(BEX[f]) + 1); if (f == 2 && ex == 0) fr &= ~((u128) 1 << 63); return s | ((u128) ex << BFR[f]) | fr; }
  if (r < 13) return s;
  if (r < 15) return s | (mask(BEX[f]) << BFR[f]) | (f == 2 ? (u128) 1 << 63 : 0);
  if (r < 17) return s | (mask(BEX[f]) << BFR[f]) | (f == 2 ? (u128) 1 << 63 : 0) | ((rnd128() & mask(BFR[f] - 1)) | 1);
  if (r < 22) { if (f == 2) fr &= ~((u128) 1 << 63); return s | fr; }                     /* subnormal */
  if (r < 40) ex = bias + rint_(140) - 70;                                                /* near one */
  else if (r < 50) { ex = bias + rint_(64); fr &= ~mask(BFR[f] - rint_(BFR[f] + 1) > 0 ? BFR[f] - rint_(BFR[f]) : 0); if (f == 2) fr |= (u128) 1 << 63; }   /* integers, few bits */
  else ex = 1 + rint_((int) mask(BEX[f]) - 1);
  if (ex < 1) ex = 1;
  if (ex > (int) mask(BEX[f]) - 1) ex = (int) mask(BEX[f]) - 1;
  return s | ((u128) ex << BFR[f]) | fr;
}

/* the routines: libgcc's and ours */
#define DECL2(T, R, N) R __bid_##N(T, T); R __ccl_bid_##N(T, T);
#define DECL1(T, R, N) R __bid_##N(T); R __ccl_bid_##N(T);
#define KIND(T, S) DECL2(T, T, add##S##3) DECL2(T, T, sub##S##3) DECL2(T, T, mul##S##3) DECL2(T, T, div##S##3) \
  DECL2(T, long, eq##S##2) DECL2(T, long, ne##S##2) DECL2(T, long, lt##S##2) DECL2(T, long, le##S##2) DECL2(T, long, gt##S##2) DECL2(T, long, ge##S##2) \
  DECL1(int, T, floatsi##S) DECL1(unsigned, T, floatunssi##S) DECL1(long, T, floatdi##S) DECL1(u64, T, floatunsdi##S) \
  DECL1(T, int, fix##S##si) DECL1(T, unsigned, fixuns##S##si) DECL1(T, long, fix##S##di) DECL1(T, u64, fixuns##S##di)
KIND(_Decimal32, sd) KIND(_Decimal64, dd) KIND(_Decimal128, td)
DECL1(_Decimal32, _Decimal64, extendsddd2) DECL1(_Decimal32, _Decimal128, extendsdtd2) DECL1(_Decimal64, _Decimal128, extendddtd2)
DECL1(_Decimal64, _Decimal32, truncddsd2) DECL1(_Decimal128, _Decimal32, trunctdsd2) DECL1(_Decimal128, _Decimal64, trunctddd2)
DECL1(float, _Decimal32, extendsfsd) DECL1(float, _Decimal64, extendsfdd) DECL1(float, _Decimal128, extendsftd)
DECL1(double, _Decimal32, truncdfsd) DECL1(double, _Decimal64, extenddfdd) DECL1(double, _Decimal128, extenddftd)
DECL1(long double, _Decimal32, truncxfsd) DECL1(long double, _Decimal64, truncxfdd) DECL1(long double, _Decimal128, extendxftd)
DECL1(_Decimal32, float, truncsdsf) DECL1(_Decimal32, double, extendsddf) DECL1(_Decimal32, long double, extendsdxf)
DECL1(_Decimal64, float, truncddsf) DECL1(_Decimal64, double, truncdddf) DECL1(_Decimal64, long double, extendddxf)
DECL1(_Decimal128, float, trunctdsf) DECL1(_Decimal128, double, trunctddf) DECL1(_Decimal128, long double, trunctdxf)
/* the quad: libgcc's takes and gives __float128; ours the quad's bits in a _Decimal128 */
_Decimal32 __bid_trunctfsd(__float128); _Decimal32 __ccl_bid_trunctfsd(_Decimal128);
_Decimal64 __bid_trunctfdd(__float128); _Decimal64 __ccl_bid_trunctfdd(_Decimal128);
_Decimal128 __bid_extendtftd(__float128); _Decimal128 __ccl_bid_extendtftd(_Decimal128);
__float128 __bid_extendsdtf(_Decimal32); _Decimal128 __ccl_bid_extendsdtf(_Decimal32);
__float128 __bid_extendddtf(_Decimal64); _Decimal128 __ccl_bid_extendddtf(_Decimal64);
__float128 __bid_trunctdtf(_Decimal128); _Decimal128 __ccl_bid_trunctdtf(_Decimal128);

static u128 bits_of(const void *p, int n) { u128 r = 0; memcpy(&r, p, n); return r; }
#define BITS(v, n) ({ __typeof__(v) _v = (v); bits_of(&_v, n); })
static void of_bits(void *p, u128 b, int n) { memcpy(p, &b, n); }
static int fails, total, shown[200];
static const char *names[200]; static int nnames;
static int fid(const char *n) { int i; for (i = 0; i < nnames; i++) if (!strcmp(names[i], n)) return i; names[nnames] = n; return nnames++; }
static void ph(u128 v) { printf("%016llx%016llx", (unsigned long long) (v >> 64), (unsigned long long) v); }
static int failsby[200], totalby[200];
/* a NaN answer is held to its class and sign alone where its payload is libgcc's own plumbing (C reads none) */
static int nanlike(const char *n, u128 got, u128 want) {
  int dw = 0, bw = 0, len = (int) strlen(n);
  if (!strncmp(n, "extendsd", 8) || !strncmp(n, "extenddd", 8) || !strncmp(n, "trunctd", 7) || !strncmp(n, "truncdd", 7) || !strncmp(n, "truncsd", 7)) {
    if (n[len - 1] == '2' && strcmp(n, "truncddsd2")) return 0; }
  const char *t = n + len - 2;
  if (n[len - 1] == '3') t = n + len - 3;
  if (!strcmp(n + len - 2, "sf")) bw = 32; else if (!strcmp(n + len - 2, "df")) bw = 64; else if (!strcmp(n + len - 2, "xf")) bw = 80; else if (!strcmp(n + len - 2, "tf")) bw = 128;
  if (!strncmp(t, "sd", 2)) dw = 32; else if (!strncmp(t, "dd", 2)) dw = 64; else if (!strncmp(t, "td", 2)) dw = 128;
  if (!strcmp(n, "truncddsd2")) dw = 32;
  if (bw) { int fb = bw == 32 ? 23 : bw == 64 ? 52 : bw == 80 ? 64 : 112, eb = bw == 32 ? 8 : bw == 64 ? 11 : 15;
    u128 em = mask(eb) << fb; int qb = bw == 80 ? 62 : fb - 1;
    if ((want & em) != em || (want & mask(bw == 80 ? 63 : fb)) == 0) return 0;
    return (got & em) == em && (got & mask(bw == 80 ? 63 : fb)) != 0 && ((got >> qb) & 1) == ((want >> qb) & 1) && ((got >> (fb + eb)) & 1) == ((want >> (fb + eb)) & 1); }
  if (dw) { if (((want >> (dw - 6)) & 31) != 31) return 0;
    return ((got >> (dw - 7)) & 127) == ((want >> (dw - 7)) & 127); }
  return 0;
}
static void check(const char *n, u128 a, u128 b, u128 got, u128 want) {
  int i = fid(n);
  totalby[i]++; total++;
  if (got == want || nanlike(n, got, want)) return;
  failsby[i]++; fails++;
  if (shown[i]++ < 4) { printf("FAIL %s(", n); ph(a); printf(", "); ph(b); printf(") ours "); ph(got); printf(" libgcc "); ph(want); printf("\n"); }
}
#define DECW(k) (k == 0 ? 4 : k == 1 ? 8 : 16)
#define T2(k, T, N) { T x, y; int e; u128 a = rdec(k, -100000, &e), b = rdec(k, e, 0); of_bits(&x, a, DECW(k)); of_bits(&y, b, DECW(k)); \
  if (rint_(8) == 0) { y = x; b = a; } \
  check(#N, a, b, BITS(__ccl_bid_##N(x, y), DECW(k)), BITS(__bid_##N(x, y), DECW(k))); }
#define C2(k, T, N) { T x, y; int e; u128 a = rdec(k, -100000, &e), b = rdec(k, e, 0); of_bits(&x, a, DECW(k)); of_bits(&y, b, DECW(k)); \
  if (rint_(8) == 0) { y = x; b = a; } \
  check(#N, a, b, (u128) (u64) __ccl_bid_##N(x, y), (u128) (u64) __bid_##N(x, y)); }
#define FROMI(k, T, IT, N, GEN) { IT i = (IT) (GEN); check(#N, (u128) (u64) i, 0, BITS(__ccl_bid_##N(i), DECW(k)), BITS(__bid_##N(i), DECW(k))); }
/* libgcc's unsigned conversions answer 0 for 2^31 (to 32 bits) and for 2^63 (to 64), whose `integer indefinite' they
   map to 0; the runtime answers the value */
#define TOI(k, T, RT, N) { T x; u128 a = rdec1(k); of_bits(&x, a, DECW(k)); RT g = __ccl_bid_##N(x), w = __bid_##N(x); \
  if (w == 0 && sizeof(RT) == 4 && (RT) -1 > 0 && (u64) g == 0x80000000ull) w = g; \
  if (w == 0 && sizeof(RT) == 8 && (RT) -1 > 0 && (u64) g == 0x8000000000000000ull) w = g; \
  check(#N, a, 0, (u128) (u64) g, (u128) (u64) w); }
#define D2D(kf, TF, kt, TT, N) { TF x; u128 a = rdec1(kf); of_bits(&x, a, DECW(kf)); check(#N, a, 0, BITS(__ccl_bid_##N(x), DECW(kt)), BITS(__bid_##N(x), DECW(kt))); }
#define B2D(f, BT, BW, kt, N) { BT v; u128 a = rbin(f); of_bits(&v, a, BW); check(#N, a, 0, BITS(__ccl_bid_##N(v), DECW(kt)), BITS(__bid_##N(v), DECW(kt))); }
static long rlong(void) { int r = rint_(4); u64 v = rnd(); if (r == 0) return (long) (v >> rint_(64)); if (r == 1) return -(long) (v >> rint_(64)); if (r == 2) return (long) (v % 100000); return (long) v; }
#define KINDTESTS(k, T, S) \
  T2(k, T, add##S##3) T2(k, T, sub##S##3) T2(k, T, mul##S##3) T2(k, T, div##S##3) \
  C2(k, T, eq##S##2) C2(k, T, ne##S##2) C2(k, T, lt##S##2) C2(k, T, le##S##2) C2(k, T, gt##S##2) C2(k, T, ge##S##2) \
  FROMI(k, T, int, floatsi##S, rlong()) FROMI(k, T, unsigned, floatunssi##S, rlong()) FROMI(k, T, long, floatdi##S, rlong()) FROMI(k, T, u64, floatunsdi##S, rlong()) \
  TOI(k, T, int, fix##S##si) TOI(k, T, unsigned, fixuns##S##si) TOI(k, T, long, fix##S##di) TOI(k, T, u64, fixuns##S##di)
/* THE INTEGERS' EDGES: each kind's values about 2^31, 2^32, 2^63 and 2^64, to every integer routine */
static void edges(void) {
  static const u64 at[] = {0x7fffffffull, 0x80000000ull, 0xffffffffull, 0x100000000ull, 0x7fffffffffffffffull, 0x8000000000000000ull, 0xffffffffffffffffull};
  int k, i, j, neg;
  for (k = 0; k < 3; k++) for (i = 0; i < 7; i++) for (j = -1; j <= 1; j++) for (neg = 0; neg < 2; neg++) {
    u128 c = (u128) at[i] + (u128) (j + 1) - 1, b;
    int e = 0;
    while (c >= p10(P[k])) { c /= 10; e++; }
    b = pack(k, neg, c, e);
    if (k == 0) { _Decimal32 x; of_bits(&x, b, 4); int a1 = __ccl_bid_fixsdsi(x), a2 = __bid_fixsdsi(x); check("edge fixsdsi", b, 0, (u128) (u64) a1, (u128) (u64) a2);
      long l1 = __ccl_bid_fixsddi(x), l2 = __bid_fixsddi(x); check("edge fixsddi", b, 0, (u128) (u64) l1, (u128) (u64) l2); }
    if (k == 1) { _Decimal64 x; of_bits(&x, b, 8); int a1 = __ccl_bid_fixddsi(x), a2 = __bid_fixddsi(x); check("edge fixddsi", b, 0, (u128) (u64) a1, (u128) (u64) a2);
      long l1 = __ccl_bid_fixdddi(x), l2 = __bid_fixdddi(x); check("edge fixdddi", b, 0, (u128) (u64) l1, (u128) (u64) l2);
      unsigned u1 = __ccl_bid_fixunsddsi(x), u2 = __bid_fixunsddsi(x); if (u2 == 0 && u1 == 0x80000000u) u2 = u1; check("edge fixunsddsi", b, 0, u1, u2);
      u64 v1 = __ccl_bid_fixunsdddi(x), v2 = __bid_fixunsdddi(x); if (v2 == 0 && v1 == 0x8000000000000000ull) v2 = v1; check("edge fixunsdddi", b, 0, v1, v2); }
    if (k == 2) { _Decimal128 x; of_bits(&x, b, 16); int a1 = __ccl_bid_fixtdsi(x), a2 = __bid_fixtdsi(x); check("edge fixtdsi", b, 0, (u128) (u64) a1, (u128) (u64) a2);
      long l1 = __ccl_bid_fixtddi(x), l2 = __bid_fixtddi(x); check("edge fixtddi", b, 0, (u128) (u64) l1, (u128) (u64) l2);
      unsigned u1 = __ccl_bid_fixunstdsi(x), u2 = __bid_fixunstdsi(x); if (u2 == 0 && u1 == 0x80000000u) u2 = u1; check("edge fixunstdsi", b, 0, u1, u2);
      u64 v1 = __ccl_bid_fixunstddi(x), v2 = __bid_fixunstddi(x); if (v2 == 0 && v1 == 0x8000000000000000ull) v2 = v1; check("edge fixunstddi", b, 0, v1, v2); }
  }
}
/* TIES: exact results one digit past the kind's that end in 5, and binary values whose decimal digits end so */
static u128 rcoef(int k, int nd) { u128 c = rnd128() % p10(nd); if (c < p10(nd - 1)) c += p10(nd - 1); return c; }
static void ties(void) {
  int k, i;
  for (k = 0; k < 3; k++) {
    int p = P[k], w = k == 0 ? 4 : k == 1 ? 8 : 16;
    for (i = 0; i < 200; i++) {
      int e = rint_(2 * p) - p, neg = rint_(2);
      u128 a = pack(k, neg, rcoef(k, p), e + 1), b = pack(k, rint_(2) ? neg : !neg, 5, e), r1, r2;
      u128 x5 = pack(k, neg, rcoef(k, p - 1) * 10 + 1 + 2 * (u128) rint_(5), 0), y2 = pack(k, 0, 2, 0);
      u128 m1 = pack(k, neg, p10(p - 1) + rnd128() % p10(p - 2), e), m2 = pack(k, 0, 15, 0);
      if (k == 0) { _Decimal32 x, y; of_bits(&x, a, 4); of_bits(&y, b, 4);
        check("tie addsd3", a, b, BITS(__ccl_bid_addsd3(x, y), 4), BITS(__bid_addsd3(x, y), 4));
        of_bits(&x, x5, 4); of_bits(&y, y2, 4); check("tie divsd3", x5, y2, BITS(__ccl_bid_divsd3(x, y), 4), BITS(__bid_divsd3(x, y), 4));
        of_bits(&x, m1, 4); of_bits(&y, m2, 4); check("tie mulsd3", m1, m2, BITS(__ccl_bid_mulsd3(x, y), 4), BITS(__bid_mulsd3(x, y), 4)); }
      if (k == 1) { _Decimal64 x, y; of_bits(&x, a, 8); of_bits(&y, b, 8);
        check("tie adddd3", a, b, BITS(__ccl_bid_adddd3(x, y), 8), BITS(__bid_adddd3(x, y), 8));
        of_bits(&x, x5, 8); of_bits(&y, y2, 8); check("tie divdd3", x5, y2, BITS(__ccl_bid_divdd3(x, y), 8), BITS(__bid_divdd3(x, y), 8));
        of_bits(&x, m1, 8); of_bits(&y, m2, 8); check("tie muldd3", m1, m2, BITS(__ccl_bid_muldd3(x, y), 8), BITS(__bid_muldd3(x, y), 8)); }
      if (k == 2) { _Decimal128 x, y; of_bits(&x, a, 16); of_bits(&y, b, 16);
        check("tie addtd3", a, b, BITS(__ccl_bid_addtd3(x, y), 16), BITS(__bid_addtd3(x, y), 16));
        of_bits(&x, x5, 16); of_bits(&y, y2, 16); check("tie divtd3", x5, y2, BITS(__ccl_bid_divtd3(x, y), 16), BITS(__bid_divtd3(x, y), 16));
        of_bits(&x, m1, 16); of_bits(&y, m2, 16); check("tie multd3", m1, m2, BITS(__ccl_bid_multd3(x, y), 16), BITS(__bid_multd3(x, y), 16)); }
      (void) r1; (void) r2; (void) w;
    }
  }
  /* m x 2^E for small odd m over every exponent: exact decimal digits of every length, their ties among them */
  for (i = -1080; i <= 1030; i++) {
    int m;
    for (m = 1; m < 40; m += 2) {
      double d = __builtin_ldexp((double) m, i); float f = (float) __builtin_ldexpf((float) m, i < -160 ? -160 : i > 120 ? 120 : i);
      long double l = __builtin_ldexpl((long double) m, i * 15);
      check("pow2 extenddfdd", BITS(d, 8), 0, BITS(__ccl_bid_extenddfdd(d), 8), BITS(__bid_extenddfdd(d), 8));
      check("pow2 truncdfsd", BITS(d, 8), 0, BITS(__ccl_bid_truncdfsd(d), 4), BITS(__bid_truncdfsd(d), 4));
      check("pow2 extenddftd", BITS(d, 8), 0, BITS(__ccl_bid_extenddftd(d), 16), BITS(__bid_extenddftd(d), 16));
      check("pow2 extendsfsd", BITS(f, 4), 0, BITS(__ccl_bid_extendsfsd(f), 4), BITS(__bid_extendsfsd(f), 4));
      check("pow2 extendsfdd", BITS(f, 4), 0, BITS(__ccl_bid_extendsfdd(f), 8), BITS(__bid_extendsfdd(f), 8));
      check("pow2 truncxfdd", BITS(l, 10), 0, BITS(__ccl_bid_truncxfdd(l), 8), BITS(__bid_truncxfdd(l), 8));
      check("pow2 extendxftd", BITS(l, 10), 0, BITS(__ccl_bid_extendxftd(l), 16), BITS(__bid_extendxftd(l), 16));
    }
  }
}
int main(int argc, char **argv) {
  int n = argc > 1 ? atoi(argv[1]) : 10000, i;
  if (argc > 2) rs = strtoull(argv[2], 0, 0);
  for (i = 0; i < n; i++) {
    KINDTESTS(0, _Decimal32, sd) KINDTESTS(1, _Decimal64, dd) KINDTESTS(2, _Decimal128, td)
    D2D(0, _Decimal32, 1, _Decimal64, extendsddd2) D2D(0, _Decimal32, 2, _Decimal128, extendsdtd2) D2D(1, _Decimal64, 2, _Decimal128, extendddtd2)
    D2D(1, _Decimal64, 0, _Decimal32, truncddsd2) D2D(2, _Decimal128, 0, _Decimal32, trunctdsd2) D2D(2, _Decimal128, 1, _Decimal64, trunctddd2)
    B2D(0, float, 4, 0, extendsfsd) B2D(0, float, 4, 1, extendsfdd) B2D(0, float, 4, 2, extendsftd)
    B2D(1, double, 8, 0, truncdfsd) B2D(1, double, 8, 1, extenddfdd) B2D(1, double, 8, 2, extenddftd)
    B2D(2, long double, 10, 0, truncxfsd) B2D(2, long double, 10, 1, truncxfdd) B2D(2, long double, 10, 2, extendxftd)
    { __float128 q; _Decimal128 qd; u128 a = rbin(3); of_bits(&q, a, 16); of_bits(&qd, a, 16);
      check("trunctfsd", a, 0, BITS(__ccl_bid_trunctfsd(qd), 4), BITS(__bid_trunctfsd(q), 4));
      check("trunctfdd", a, 0, BITS(__ccl_bid_trunctfdd(qd), 8), BITS(__bid_trunctfdd(q), 8));
      check("extendtftd", a, 0, BITS(__ccl_bid_extendtftd(qd), 16), BITS(__bid_extendtftd(q), 16)); }
    { _Decimal32 x; u128 a = rdec_canon(0); of_bits(&x, a, 4);
      check("truncsdsf", a, 0, BITS(__ccl_bid_truncsdsf(x), 4), BITS(__bid_truncsdsf(x), 4));
      check("extendsddf", a, 0, BITS(__ccl_bid_extendsddf(x), 8), BITS(__bid_extendsddf(x), 8));
      check("extendsdxf", a, 0, BITS(__ccl_bid_extendsdxf(x), 10), BITS(__bid_extendsdxf(x), 10));
      check("extendsdtf", a, 0, BITS(__ccl_bid_extendsdtf(x), 16), BITS(__bid_extendsdtf(x), 16)); }
    { _Decimal64 x; u128 a = rdec_canon(1); of_bits(&x, a, 8);
      check("truncddsf", a, 0, BITS(__ccl_bid_truncddsf(x), 4), BITS(__bid_truncddsf(x), 4));
      check("truncdddf", a, 0, BITS(__ccl_bid_truncdddf(x), 8), BITS(__bid_truncdddf(x), 8));
      check("extendddxf", a, 0, BITS(__ccl_bid_extendddxf(x), 10), BITS(__bid_extendddxf(x), 10));
      check("extendddtf", a, 0, BITS(__ccl_bid_extendddtf(x), 16), BITS(__bid_extendddtf(x), 16)); }
    { _Decimal128 x; u128 a = rdec_canon(2); of_bits(&x, a, 16);
      check("trunctdsf", a, 0, BITS(__ccl_bid_trunctdsf(x), 4), BITS(__bid_trunctdsf(x), 4));
      check("trunctddf", a, 0, BITS(__ccl_bid_trunctddf(x), 8), BITS(__bid_trunctddf(x), 8));
      check("trunctdxf", a, 0, BITS(__ccl_bid_trunctdxf(x), 10), BITS(__bid_trunctdxf(x), 10));
      check("trunctdtf", a, 0, BITS(__ccl_bid_trunctdtf(x), 16), BITS(__bid_trunctdtf(x), 16)); }
  }
  ties();
  edges();
  for (i = 0; i < nnames; i++) if (failsby[i]) printf("  %-14s %d of %d\n", names[i], failsby[i], totalby[i]);
  printf("%d of %d differ, %d routines\n", fails, total, nnames);
  return fails != 0;
}
