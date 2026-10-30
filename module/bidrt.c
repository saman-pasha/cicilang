/* bidrt.c: THE DECIMAL RUNTIME OF THE COMPILER (0.243). Every routine the lowering calls for C23's _Decimal32, _Decimal64
   and _Decimal128 -- the arithmetic, the comparisons, the conversions between the decimal kinds, to and from the integers
   and to and from the binary floating types -- with the conversions of a 128-bit integer (0.137) and of a _BitInt past 128
   bits (0.160). They are libgcc's routines by name, `__ccl_bid_' for `__bid_' (`__ccl_bid_adddd3' ...), and as libgcc's
   answer, its tests the reference (test/c/link/decrt.c); written here from the IEEE 754-2008 decimal formats, so that a
   machine without libgcc's decimal runtime (a Mac) links a decimal program. Compiled by cicilang itself into
   library/ccl_bidrt.pl (module/gen-bidrt.sh), whose functions the lowering puts into a module, internal, each with the
   functions it calls (ccl_ir.pl, ir_dec_rt/1). Never edited in the generated file.
   A value is its BID encoding (the binary integer decimal), carried as a float, a double and an fp128; nothing here
   computes on a decimal as one: a value is taken apart into its class, sign, coefficient and quantum exponent, the
   result made exactly in integers, a big one where it needs more than 128 bits, and rounded ONCE, half to even (the one
   rounding direction: C has no way to set another), into its format. No exception flag is kept (libgcc keeps its own,
   which no standard function reads). */
typedef unsigned __int128 ccl_u128;
typedef unsigned long ccl_u64;

/* THE DECIMAL KINDS, k: 0 _Decimal32 (sd), 1 _Decimal64 (dd), 2 _Decimal128 (td) -- the digits, the bias (the least quantum
   exponent's negation), the greatest quantum exponent, the width and the exponent field's bits */
static int ccl_dprec(int k) { return k == 0 ? 7 : k == 1 ? 16 : 34; }
static int ccl_dbias(int k) { return k == 0 ? 101 : k == 1 ? 398 : 6176; }
static int ccl_demax(int k) { return k == 0 ? 90 : k == 1 ? 369 : 6111; }
static int ccl_dwidth(int k) { return k == 0 ? 32 : k == 1 ? 64 : 128; }
static int ccl_debits(int k) { return k == 0 ? 8 : k == 1 ? 10 : 14; }
static ccl_u128 ccl_p10(int n) { ccl_u128 r = 1; while (n-- > 0) r *= 10; return r; }
static ccl_u128 ccl_mask(int n) { return n >= 128 ? ~(ccl_u128) 0 : ((ccl_u128) 1 << n) - 1; }
static int ccl_digits(ccl_u128 c) { int d = 0; while (c != 0) { c /= 10; d++; } return d; }

/* A DECIMAL TAKEN APART: its class, answered (0 a finite value, 1 an infinity, 2 a quiet NaN, 3 a signaling NaN), its sign,
   its quantum exponent and its coefficient (a NaN's payload, 0 where it is not canonical); a coefficient past the kind's
   digits is not canonical, and is a zero. No struct: a named type of the runtime's would meet the program's in its module. */
static int ccl_dec_get(int k, ccl_u128 b, int *neg, int *e, ccl_u128 *c) {
  int w = ccl_dwidth(k), eb = ccl_debits(k), p = ccl_dprec(k);
  unsigned g = (unsigned) ((b >> (w - 6)) & 31);
  *neg = (int) ((b >> (w - 1)) & 1);
  *e = 0;
  if (g == 31) {
    *c = b & ccl_mask(w - 4 - eb);
    if (*c >= ccl_p10(p - 1)) *c = 0;
    return ((b >> (w - 7)) & 1) ? 3 : 2;
  }
  *c = 0;
  if (g == 30) return 1;
  if (((b >> (w - 3)) & 3) == 3) {
    *e = (int) ((b >> (w - 3 - eb)) & ccl_mask(eb)) - ccl_dbias(k);
    *c = (b & ccl_mask(w - 3 - eb)) | ((ccl_u128) 4 << (w - 3 - eb));
  } else {
    *e = (int) ((b >> (w - 1 - eb)) & ccl_mask(eb)) - ccl_dbias(k);
    *c = b & ccl_mask(w - 1 - eb);
  }
  if (*c >= ccl_p10(p)) *c = 0;
  return 0;
}
static ccl_u128 ccl_dec_sign(int k, int neg) { return neg ? (ccl_u128) 1 << (ccl_dwidth(k) - 1) : 0; }
static ccl_u128 ccl_dec_pack(int k, int neg, ccl_u128 c, int e) {
  int w = ccl_dwidth(k), eb = ccl_debits(k);
  ccl_u128 be = (ccl_u128) (e + ccl_dbias(k));
  if ((c >> (w - 1 - eb)) == 0) return ccl_dec_sign(k, neg) | (be << (w - 1 - eb)) | c;
  return ccl_dec_sign(k, neg) | ((ccl_u128) 3 << (w - 3)) | (be << (w - 3 - eb)) | (c & ccl_mask(w - 3 - eb));
}
static ccl_u128 ccl_dec_inf(int k, int neg) { return ccl_dec_sign(k, neg) | ((ccl_u128) 30 << (ccl_dwidth(k) - 6)); }
static ccl_u128 ccl_dec_nan(int k, int neg, ccl_u128 payload) {
  return ccl_dec_sign(k, neg) | ((ccl_u128) 31 << (ccl_dwidth(k) - 6)) | (payload < ccl_p10(ccl_dprec(k) - 1) ? payload : 0);
}

/* A BIG NUMBER: its 64-bit limbs, the least first, and their count, no zero limb on top. CCL_BN limbs hold the greatest
   number a conversion makes: a binary float's least value's digits, 5^16494 times its significand (38,411 bits) */
#define CCL_BN 640
static int ccl_bn_norm(const ccl_u64 *a, int n) { while (n > 0 && a[n - 1] == 0) n--; return n; }
static int ccl_bn_set(ccl_u64 *a, ccl_u128 v) { a[0] = (ccl_u64) v; a[1] = (ccl_u64) (v >> 64); return ccl_bn_norm(a, 2); }
static ccl_u128 ccl_bn_u128(const ccl_u64 *a, int n) { return n == 0 ? 0 : n == 1 ? (ccl_u128) a[0] : (ccl_u128) a[0] | (ccl_u128) a[1] << 64; }
static int ccl_bn_mul1(ccl_u64 *a, int n, ccl_u64 m) {
  ccl_u128 carry = 0; int i;
  for (i = 0; i < n; i++) { ccl_u128 t = (ccl_u128) a[i] * m + carry; a[i] = (ccl_u64) t; carry = t >> 64; }
  if (carry != 0) { a[n] = (ccl_u64) carry; n++; }
  return n;
}
static int ccl_bn_mul10k(ccl_u64 *a, int n, int k) {
  while (k >= 19) { n = ccl_bn_mul1(a, n, 10000000000000000000ul); k -= 19; }
  return k > 0 ? ccl_bn_mul1(a, n, (ccl_u64) ccl_p10(k)) : n;
}
static int ccl_bn_mul5k(ccl_u64 *a, int n, int k) {
  ccl_u64 m = 1;
  while (k >= 27) { n = ccl_bn_mul1(a, n, 7450580596923828125ul); k -= 27; }
  while (k-- > 0) m *= 5;
  return m == 1 ? n : ccl_bn_mul1(a, n, m);
}
static int ccl_bn_mul(ccl_u64 *r, const ccl_u64 *a, int an, const ccl_u64 *b, int bn) {
  int i, j;
  for (i = 0; i < an + bn; i++) r[i] = 0;
  for (i = 0; i < an; i++) {
    ccl_u128 carry = 0;
    for (j = 0; j < bn; j++) { ccl_u128 t = (ccl_u128) a[i] * b[j] + r[i + j] + carry; r[i + j] = (ccl_u64) t; carry = t >> 64; }
    r[i + bn] = (ccl_u64) carry;
  }
  return ccl_bn_norm(r, an + bn);
}
static int ccl_bn_add(ccl_u64 *a, int an, const ccl_u64 *b, int bn) {
  ccl_u64 carry = 0; int i, n = an > bn ? an : bn;
  for (i = 0; i < n; i++) {
    ccl_u64 x = i < an ? a[i] : 0, y = i < bn ? b[i] : 0, s = x + y, t = s + carry;
    carry = (ccl_u64) ((s < x) | (t < s));
    a[i] = t;
  }
  if (carry != 0) { a[n] = 1; n++; }
  return n;
}
static int ccl_bn_sub(ccl_u64 *a, int an, const ccl_u64 *b, int bn) {   /* a - b, a not below b */
  ccl_u64 borrow = 0; int i;
  for (i = 0; i < an; i++) {
    ccl_u64 x = a[i], y = i < bn ? b[i] : 0, d = x - y, t = d - borrow;
    borrow = (ccl_u64) ((x < y) | (d < borrow));
    a[i] = t;
  }
  return ccl_bn_norm(a, an);
}
static int ccl_bn_cmp(const ccl_u64 *a, int an, const ccl_u64 *b, int bn) {
  int i;
  if (an != bn) return an < bn ? -1 : 1;
  for (i = an - 1; i >= 0; i--) if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
  return 0;
}
static int ccl_bn_bits(const ccl_u64 *a, int n) {
  ccl_u64 t; int b = 0;
  if (n == 0) return 0;
  t = a[n - 1];
  while (t != 0) { t >>= 1; b++; }
  return 64 * (n - 1) + b;
}
static int ccl_bn_shl(ccl_u64 *a, int n, int s) {
  int w = s / 64, b = s % 64, i;
  if (n == 0) return 0;
  if (b == 0) { for (i = n - 1; i >= 0; i--) a[i + w] = a[i]; a[n + w] = 0; }
  else {
    ccl_u64 hi = a[n - 1] >> (64 - b);
    for (i = n - 1; i > 0; i--) a[i + w] = (a[i] << b) | (a[i - 1] >> (64 - b));
    a[w] = a[0] << b;
    a[n + w] = hi;
  }
  for (i = 0; i < w; i++) a[i] = 0;
  return ccl_bn_norm(a, n + w + 1);
}
static int ccl_bn_shr1(ccl_u64 *a, int n) {
  int i;
  for (i = 0; i + 1 < n; i++) a[i] = (a[i] >> 1) | (a[i + 1] << 63);
  if (n > 0) a[n - 1] >>= 1;
  return ccl_bn_norm(a, n);
}
static int ccl_bn_bit(const ccl_u64 *a, int n, int i) { return i / 64 < n ? (int) ((a[i / 64] >> (i % 64)) & 1) : 0; }
static int ccl_bn_any_below(const ccl_u64 *a, int n, int i) {   /* a bit below bit i set */
  int j;
  for (j = 0; j < i / 64 && j < n; j++) if (a[j] != 0) return 1;
  return i / 64 < n && (a[i / 64] & (((ccl_u64) 1 << (i % 64)) - 1)) != 0;
}
static ccl_u128 ccl_bn_shr_u128(const ccl_u64 *a, int n, int s) {   /* a >> s, below 2^128 */
  int w = s / 64, b = s % 64, i;
  ccl_u128 r = 0;
  for (i = 2; i >= 0; i--) {
    ccl_u128 limb = w + i < n ? (ccl_u128) a[w + i] : 0;
    if (b == 0) { if (i < 2) r |= limb << (64 * i); }
    else r |= (64 * i - b >= 0 ? limb << (64 * i - b) : limb >> (b - 64 * i));
  }
  return r;
}
/* the quotient of a by b, below 2^128, by the digits of a long division in base two: a is left the remainder, b scratch */
static ccl_u128 ccl_bn_divq(ccl_u64 *a, int *an, ccl_u64 *b, int bn) {
  ccl_u128 q = 0; int t, i;
  if (ccl_bn_cmp(a, *an, b, bn) < 0) return 0;
  t = ccl_bn_bits(a, *an) - ccl_bn_bits(b, bn);
  bn = ccl_bn_shl(b, bn, t);
  for (i = t; i >= 0; i--) {
    if (ccl_bn_cmp(a, *an, b, bn) >= 0) { *an = ccl_bn_sub(a, *an, b, bn); q |= (ccl_u128) 1 << i; }
    bn = ccl_bn_shr1(b, bn);
  }
  return q;
}
/* the count of a's decimal digits, from its bits: floor((L - 1) log10 2) is at most one past the least power of ten not
   above a, which the products by ten then pass */
static int ccl_bn_digits(const ccl_u64 *a, int n) {
  ccl_u64 p[CCL_BN]; int pn, d, L = ccl_bn_bits(a, n);
  if (L == 0) return 0;
  d = (int) ((ccl_u64) (L - 1) * 30102999566ul / 100000000000ul);
  if (d > 0) d--;
  pn = ccl_bn_set(p, 1);
  pn = ccl_bn_mul10k(p, pn, d);
  while (ccl_bn_cmp(a, n, p, pn) >= 0) { pn = ccl_bn_mul1(p, pn, 10); d++; }
  return d;
}

/* THE ONE DECIMAL ROUNDING: the value (c + f) x 10^e, c exact, f in [0, 1) and not zero where sticky is set -- then c has
   more digits than the kind, so the first digit dropped is c's -- rounded half to even to the kind's digits, below the
   least exponent to the least exponent's place (a subnormal, or a zero), and past the greatest an infinity where no zero
   on the right makes room. An exact value whose digits fit keeps its exponent, the operation's preferred one. */
static ccl_u128 ccl_dec_round(int k, int neg, ccl_u64 *c, int cn, int e, int sticky) {
  int p = ccl_dprec(k), emin = -ccl_dbias(k), emax = ccl_demax(k), d = ccl_bn_digits(c, cn), shift = d > p ? d - p : 0;
  unsigned rd = 0;
  ccl_u128 q;
  if (e + shift < emin) shift = emin - e;
  if (shift > d) { q = 0; sticky |= cn != 0; e += shift; }
  else if (shift > 0) {
    ccl_u64 t[CCL_BN]; int tn = ccl_bn_set(t, 1);
    ccl_u128 q1;
    tn = ccl_bn_mul10k(t, tn, shift - 1);
    q1 = ccl_bn_divq(c, &cn, t, tn);
    sticky |= cn != 0;
    rd = (unsigned) (q1 % 10);
    q = q1 / 10;
    e += shift;
  } else q = ccl_bn_u128(c, cn);
  if (rd > 5 || (rd == 5 && (sticky || (q & 1) != 0))) { q++; if (q == ccl_p10(p)) { q /= 10; e++; } }
  if (e > emax) {
    if (q == 0) e = emax;
    else {
      while (e > emax && q < ccl_p10(p - 1)) { q *= 10; e--; }
      if (e > emax) return ccl_dec_inf(k, neg);
    }
  }
  return ccl_dec_pack(k, neg, q, e);
}
static ccl_u128 ccl_dec_round128(int k, int neg, ccl_u128 c, int e, int sticky) {
  ccl_u64 a[4]; int an = ccl_bn_set(a, c);
  return ccl_dec_round(k, neg, a, an, e, sticky);
}

/* THE ARITHMETIC. A NaN operand answers itself made quiet, the first one's; an invalid operation (an infinity less itself,
   a zero times an infinity, 0/0, an infinity over one) the quiet NaN with no payload. */
static ccl_u128 ccl_dec_add(int k, ccl_u128 xb, ccl_u128 yb, int sub) {
  int p = ccl_dprec(k), xk, yk, xs, ys, xe, ye, as, ae, bs, be, D;
  ccl_u128 xc, yc, ac, bc;
  xk = ccl_dec_get(k, xb, &xs, &xe, &xc);
  yk = ccl_dec_get(k, yb, &ys, &ye, &yc);
  if (sub && yk < 2) ys ^= 1;
  if (xk >= 2) return ccl_dec_nan(k, xs, xc);
  if (yk >= 2) return ccl_dec_nan(k, ys, yc);
  if (xk == 1) return yk == 1 && xs != ys ? ccl_dec_nan(k, 0, 0) : ccl_dec_inf(k, xs);
  if (yk == 1) return ccl_dec_inf(k, ys);
  if (xc == 0 && yc == 0) return ccl_dec_pack(k, xs & ys, 0, xe < ye ? xe : ye);
  if (xc == 0 || yc == 0) {   /* the other operand, its exponent brought toward the zero's as its digits allow */
    int ez = xc == 0 ? xe : ye;
    as = xc == 0 ? ys : xs; ae = xc == 0 ? ye : xe; ac = xc == 0 ? yc : xc;
    while (ae > ez && ac < ccl_p10(p - 1)) { ac *= 10; ae--; }
    return ccl_dec_pack(k, as, ac, ae);
  }
  if (xe >= ye) { as = xs; ae = xe; ac = xc; bs = ys; be = ye; bc = yc; }   /* a: the greater exponent */
  else { as = ys; ae = ye; ac = yc; bs = xs; be = xe; bc = xc; }
  D = ae - be;
  if (D <= 2 * p + 1) {   /* exactly, at the lesser exponent */
    ccl_u64 A[8], B[8]; int an = ccl_bn_set(A, ac), bn = ccl_bn_set(B, bc), s;
    an = ccl_bn_mul10k(A, an, D);
    if (as == bs) { an = ccl_bn_add(A, an, B, bn); return ccl_dec_round(k, as, A, an, be, 0); }
    s = ccl_bn_cmp(A, an, B, bn);
    if (s == 0) return ccl_dec_pack(k, 0, 0, be);
    if (s > 0) { an = ccl_bn_sub(A, an, B, bn); return ccl_dec_round(k, as, A, an, be, 0); }
    bn = ccl_bn_sub(B, bn, A, an);
    return ccl_dec_round(k, bs, B, bn, be, 0);
  }
  {   /* b below a hundredth of the last of a's p + 2 digits: it is the sticky digit, and a borrow where the signs differ */
    int s = p + 2 - ccl_digits(ac);
    ccl_u128 c = ac * ccl_p10(s);
    if (as != bs) c -= 1;
    return ccl_dec_round128(k, as, c, ae - s, 1);
  }
}
static ccl_u128 ccl_dec_mul(int k, ccl_u128 xb, ccl_u128 yb) {
  ccl_u64 A[2], B[2], R[4];
  int an, bn, rn, xk, yk, xs, ys, xe, ye;
  ccl_u128 xc, yc;
  xk = ccl_dec_get(k, xb, &xs, &xe, &xc);
  yk = ccl_dec_get(k, yb, &ys, &ye, &yc);
  if (xk >= 2) return ccl_dec_nan(k, xs, xc);
  if (yk >= 2) return ccl_dec_nan(k, ys, yc);
  if (xk == 1 || yk == 1) return (xk == 0 && xc == 0) || (yk == 0 && yc == 0) ? ccl_dec_nan(k, 0, 0) : ccl_dec_inf(k, xs ^ ys);
  an = ccl_bn_set(A, xc);
  bn = ccl_bn_set(B, yc);
  rn = ccl_bn_mul(R, A, an, B, bn);
  return ccl_dec_round(k, xs ^ ys, R, rn, xe + ye, 0);
}
static ccl_u128 ccl_dec_div(int k, ccl_u128 xb, ccl_u128 yb) {
  ccl_u64 A[8], B[8];
  int an, bn, s, e, pref, neg, p = ccl_dprec(k), xk, yk, xs, ys, xe, ye;
  ccl_u128 q, xc, yc;
  xk = ccl_dec_get(k, xb, &xs, &xe, &xc);
  yk = ccl_dec_get(k, yb, &ys, &ye, &yc);
  if (xk >= 2) return ccl_dec_nan(k, xs, xc);
  if (yk >= 2) return ccl_dec_nan(k, ys, yc);
  neg = xs ^ ys;
  if (xk == 1) return yk == 1 ? ccl_dec_nan(k, 0, 0) : ccl_dec_inf(k, neg);
  if (yk == 1) return ccl_dec_pack(k, neg, 0, -ccl_dbias(k));
  if (yc == 0) return xc == 0 ? ccl_dec_nan(k, 0, 0) : ccl_dec_inf(k, neg);
  pref = xe - ye;
  if (xc == 0) return ccl_dec_round128(k, neg, 0, pref, 0);
  s = p + 1 + ccl_digits(yc) - ccl_digits(xc);   /* the quotient past 10^p: a digit to round by */
  an = ccl_bn_set(A, xc);
  an = ccl_bn_mul10k(A, an, s);
  bn = ccl_bn_set(B, yc);
  q = ccl_bn_divq(A, &an, B, bn);
  e = pref - s;
  if (an == 0) while (e < pref && q % 10 == 0) { q /= 10; e++; }   /* exact: the zeros on the right dropped toward xe - ye */
  return ccl_dec_round128(k, neg, q, e, an != 0);
}
/* x against y: -1, 0 or 1, and 2 unordered */
static int ccl_dec_cmp(int k, ccl_u128 xb, ccl_u128 yb) {
  int r, ax, ay, xk, yk, xs, ys, xe, ye;
  ccl_u128 xc, yc;
  xk = ccl_dec_get(k, xb, &xs, &xe, &xc);
  yk = ccl_dec_get(k, yb, &ys, &ye, &yc);
  if (xk >= 2 || yk >= 2) return 2;
  if (xk == 1) return yk == 1 && xs == ys ? 0 : xs ? -1 : 1;
  if (yk == 1) return ys ? 1 : -1;
  if (xc == 0 && yc == 0) return 0;
  if (xc == 0) return ys ? 1 : -1;
  if (yc == 0) return xs ? -1 : 1;
  if (xs != ys) return xs ? -1 : 1;
  ax = xe + ccl_digits(xc);
  ay = ye + ccl_digits(yc);
  if (ax != ay) r = ax > ay ? 1 : -1;
  else {   /* one adjusted exponent: the coefficient of the greater exponent scaled has the other's digits */
    if (xe > ye) xc *= ccl_p10(xe - ye); else yc *= ccl_p10(ye - xe);
    r = xc == yc ? 0 : xc > yc ? 1 : -1;
  }
  return xs ? -r : r;
}
/* from one kind to another: a wider kind holds the value as it is, a narrower one rounds it; a NaN's payload keeps its
   digits on the left, as libgcc's */
static ccl_u128 ccl_dec_conv(int kf, int kt, ccl_u128 b) {
  int dp = ccl_dprec(kt) - ccl_dprec(kf), s, e, cls = 0;
  ccl_u128 c;
  cls = ccl_dec_get(kf, b, &s, &e, &c);
  if (cls >= 2) return ccl_dec_nan(kt, s, dp >= 0 ? c * ccl_p10(dp) : c / ccl_p10(-dp));
  if (cls == 1) return ccl_dec_inf(kt, s);
  return ccl_dec_round128(kt, s, c, e, 0);
}
/* the value toward zero, its magnitude below 2^64: *ok 0 past it, and for a NaN or an infinity */
static ccl_u64 ccl_dec_trunc64(int k, ccl_u128 b, int *neg, int *ok) {
  int e, cls;
  ccl_u128 m;
  cls = ccl_dec_get(k, b, neg, &e, &m);
  *ok = 0;
  if (cls != 0) return 0;
  if (m != 0 && e > 0) { if (e + ccl_digits(m) > 20) return 0; m *= ccl_p10(e); }
  else if (e < 0) m = -e > 38 ? 0 : m / ccl_p10(-e);
  if ((m >> 64) != 0) return 0;
  *ok = 1;
  return (ccl_u64) m;
}

/* THE BINARY FORMATS, f: 0 float (sf), 1 double (df), 2 x87's 80-bit long double (xf, its integer bit explicit), 3 the
   IEEE quad (tf) -- the significand's bits, the least and the greatest exponent; their bits in a 128-bit integer */
static int ccl_bprec(int f) { return f == 0 ? 24 : f == 1 ? 53 : f == 2 ? 64 : 113; }
static int ccl_bemax(int f) { return f == 0 ? 127 : f == 1 ? 1023 : 16383; }
static int ccl_bfrac(int f) { return f == 0 ? 23 : f == 1 ? 52 : f == 2 ? 64 : 112; }   /* the significand field's bits */
static int ccl_bexp(int f) { return f == 0 ? 8 : f == 1 ? 11 : 15; }
static ccl_u128 ccl_bin_sign(int f, int neg) { return neg ? (ccl_u128) 1 << (ccl_bfrac(f) + ccl_bexp(f)) : 0; }
static ccl_u128 ccl_bin_inf(int f, int neg) {
  return ccl_bin_sign(f, neg) | (ccl_mask(ccl_bexp(f)) << ccl_bfrac(f)) | (f == 2 ? (ccl_u128) 1 << 63 : 0);
}
static ccl_u128 ccl_bin_nan(int f, int neg) { return ccl_bin_inf(f, neg) | ((ccl_u128) 1 << (ccl_bfrac(f) - (f == 2 ? 2 : 1))); }
/* a binary float taken apart: its class (0 finite, 1 an infinity, 2 a NaN) and sign, the value m x 2^E */
static int ccl_bin_get(int f, ccl_u128 b, int *neg, ccl_u128 *m, int *E) {
  int fb = ccl_bfrac(f), bias = ccl_bemax(f), ex = (int) ((b >> fb) & ccl_mask(ccl_bexp(f)));
  ccl_u128 fr = b & ccl_mask(fb);
  *neg = (int) ((b >> (fb + ccl_bexp(f))) & 1);
  if (ex == (int) ccl_mask(ccl_bexp(f))) { *m = 0; *E = 0; return (fr & ccl_mask(f == 2 ? 63 : fb)) == 0 ? 1 : 2; }
  if (f == 2) { *m = fr; *E = (ex == 0 ? 1 : ex) - bias - 63; return 0; }
  if (ex == 0) { *m = fr; *E = 1 - bias - fb; return 0; }
  *m = fr | ((ccl_u128) 1 << fb);
  *E = ex - bias - fb;
  return 0;
}
/* THE ONE BINARY ROUNDING: the value (x + f) x 2^sh, x exact, f in [0, 1) and not zero where sticky is set -- then x has
   two bits more than the format keeps -- rounded half to even to the format's bits, below its least exponent to a
   subnormal or a zero, past its greatest an infinity */
static ccl_u128 ccl_bin_round(int f, int neg, ccl_u64 *x, int xn, int sh, int sticky) {
  int P = ccl_bprec(f), emax = ccl_bemax(f), emin = 1 - emax, L = ccl_bn_bits(x, xn), B, q, drop, guard = 0;
  ccl_u128 M, ex;
  if (L == 0) return ccl_bin_sign(f, neg);
  B = L - 1 + sh;
  if (B > emax) return ccl_bin_inf(f, neg);
  q = (B >= emin ? B : emin) - P + 1;
  drop = q - sh;
  if (drop <= 0) M = ccl_bn_u128(x, xn) << -drop;
  else if (drop > L) { M = 0; sticky = 1; }
  else {
    guard = ccl_bn_bit(x, xn, drop - 1);
    sticky |= ccl_bn_any_below(x, xn, drop - 1);
    M = ccl_bn_shr_u128(x, xn, drop);
  }
  if (guard && (sticky || (M & 1) != 0)) { M++; if ((M >> P) != 0) { M >>= 1; q++; } }
  if (M == 0) return ccl_bin_sign(f, neg);
  if (q + P - 1 > emax) return ccl_bin_inf(f, neg);
  ex = (M >> (P - 1)) != 0 ? (ccl_u128) (q + P - 1 + emax) : 0;
  return ccl_bin_sign(f, neg) | (ex << ccl_bfrac(f)) | (f == 2 ? M : M & ccl_mask(ccl_bfrac(f)));
}
/* a decimal to a binary format: c x 10^e exactly where e is not negative, else c x 2^s / 10^-e to past P + 2 bits, the
   remainder its sticky bit */
static ccl_u128 ccl_dec_to_bin(int k, int f, ccl_u128 b) {
  ccl_u64 X[CCL_BN];
  int xn, cls, s, e;
  ccl_u128 c;
  cls = ccl_dec_get(k, b, &s, &e, &c);
  if (cls >= 2) return ccl_bin_nan(f, s);
  if (cls == 1) return ccl_bin_inf(f, s);
  if (c == 0) return ccl_bin_sign(f, s);
  xn = ccl_bn_set(X, c);
  if (e >= 0) { xn = ccl_bn_mul10k(X, xn, e); return ccl_bin_round(f, s, X, xn, 0, 0); }
  {
    ccl_u64 T[CCL_BN], Q[4];
    int tn = ccl_bn_set(T, 1), sh, qn;
    ccl_u128 q;
    tn = ccl_bn_mul10k(T, tn, -e);
    sh = ccl_bprec(f) + 3 + ccl_bn_bits(T, tn) - ccl_bn_bits(X, xn);
    if (sh < 0) sh = 0;
    xn = ccl_bn_shl(X, xn, sh);
    q = ccl_bn_divq(X, &xn, T, tn);
    qn = ccl_bn_set(Q, q);
    return ccl_bin_round(f, s, Q, qn, -sh, xn != 0);
  }
}
/* a binary float to a decimal: m x 2^E, m odd, exactly as c x 10^e -- m 2^E where E is not negative, else m 5^-E at the
   exponent E -- then rounded: an exact value whose digits fit keeps the exponent nearest zero, an inexact one has the
   kind's digits */
static ccl_u128 ccl_bin_to_dec(int f, int k, ccl_u128 b) {
  ccl_u64 C[CCL_BN];
  int neg, E, cn, cls;
  ccl_u128 m;
  cls = ccl_bin_get(f, b, &neg, &m, &E);
  if (cls == 2) return ccl_dec_nan(k, neg, 0);
  if (cls == 1) return ccl_dec_inf(k, neg);
  if (m == 0) return ccl_dec_pack(k, neg, 0, 0);
  while ((m & 1) == 0) { m >>= 1; E++; }
  cn = ccl_bn_set(C, m);
  if (E >= 0) { cn = ccl_bn_shl(C, cn, E); return ccl_dec_round(k, neg, C, cn, 0, 0); }
  cn = ccl_bn_mul5k(C, cn, -E);
  return ccl_dec_round(k, neg, C, cn, E, 0);
}

/* THE CARRIERS: a decimal's bits from and to its float, double or fp128; a long double's from and to its 80 bits; the
   IEEE quad's carried as a _Decimal128, whose carrier is the fp128 that the quad is */
typedef union { _Decimal32 d; unsigned u; } ccl_sdw;
typedef union { _Decimal64 d; ccl_u64 u; } ccl_ddw;
typedef union { _Decimal128 d; ccl_u128 u; } ccl_tdw;
typedef union { float f; unsigned u; } ccl_sfw;
typedef union { double f; ccl_u64 u; } ccl_dfw;
typedef union { long double f; ccl_u64 w[2]; } ccl_xfw;
static ccl_u128 ccl_sd_bits(_Decimal32 x) { ccl_sdw w; w.d = x; return w.u; }
static ccl_u128 ccl_dd_bits(_Decimal64 x) { ccl_ddw w; w.d = x; return w.u; }
static ccl_u128 ccl_td_bits(_Decimal128 x) { ccl_tdw w; w.d = x; return w.u; }
static _Decimal32 ccl_sd_of(ccl_u128 b) { ccl_sdw w; w.u = (unsigned) b; return w.d; }
static _Decimal64 ccl_dd_of(ccl_u128 b) { ccl_ddw w; w.u = (ccl_u64) b; return w.d; }
static _Decimal128 ccl_td_of(ccl_u128 b) { ccl_tdw w; w.u = b; return w.d; }
static ccl_u128 ccl_sf_bits(float x) { ccl_sfw w; w.f = x; return w.u; }
static ccl_u128 ccl_df_bits(double x) { ccl_dfw w; w.f = x; return w.u; }
static ccl_u128 ccl_xf_bits(long double x) { ccl_xfw w; w.w[1] = 0; w.f = x; return (ccl_u128) w.w[0] | (ccl_u128) (w.w[1] & 0xffff) << 64; }
static float ccl_sf_of(ccl_u128 b) { ccl_sfw w; w.u = (unsigned) b; return w.f; }
static double ccl_df_of(ccl_u128 b) { ccl_dfw w; w.u = (ccl_u64) b; return w.f; }
static long double ccl_xf_of(ccl_u128 b) { ccl_xfw w; w.w[0] = (ccl_u64) b; w.w[1] = (ccl_u64) (b >> 64) & 0xffff; return w.f; }

/* THE ROUTINES, by libgcc's names */
#define CCL_ARITH(K, T, SFX, BITS, OF)                                                                              \
  T __ccl_bid_add##SFX##3(T x, T y) { return OF(ccl_dec_add(K, BITS(x), BITS(y), 0)); }                             \
  T __ccl_bid_sub##SFX##3(T x, T y) { return OF(ccl_dec_add(K, BITS(x), BITS(y), 1)); }                             \
  T __ccl_bid_mul##SFX##3(T x, T y) { return OF(ccl_dec_mul(K, BITS(x), BITS(y))); }                                \
  T __ccl_bid_div##SFX##3(T x, T y) { return OF(ccl_dec_div(K, BITS(x), BITS(y))); }                                \
  long __ccl_bid_eq##SFX##2(T x, T y) { return ccl_dec_cmp(K, BITS(x), BITS(y)) != 0; }                             \
  long __ccl_bid_ne##SFX##2(T x, T y) { return ccl_dec_cmp(K, BITS(x), BITS(y)) != 0; }                             \
  long __ccl_bid_lt##SFX##2(T x, T y) { return ccl_dec_cmp(K, BITS(x), BITS(y)) == -1 ? -1 : 0; }                   \
  long __ccl_bid_le##SFX##2(T x, T y) { int r = ccl_dec_cmp(K, BITS(x), BITS(y)); return r == -1 || r == 0 ? -1 : 1; } \
  long __ccl_bid_gt##SFX##2(T x, T y) { return ccl_dec_cmp(K, BITS(x), BITS(y)) == 1; }                             \
  long __ccl_bid_ge##SFX##2(T x, T y) { int r = ccl_dec_cmp(K, BITS(x), BITS(y)); return r == 1 || r == 0 ? 1 : -1; } \
  T __ccl_bid_floatsi##SFX(int i) { return OF(ccl_dec_round128(K, i < 0, i < 0 ? -(ccl_u128) i : (ccl_u128) i, 0, 0)); } \
  T __ccl_bid_floatunssi##SFX(unsigned i) { return OF(ccl_dec_round128(K, 0, i, 0, 0)); }                           \
  T __ccl_bid_floatdi##SFX(long i) { return OF(ccl_dec_round128(K, i < 0, i < 0 ? -(ccl_u128) i : (ccl_u128) i, 0, 0)); } \
  T __ccl_bid_floatunsdi##SFX(ccl_u64 i) { return OF(ccl_dec_round128(K, 0, i, 0, 0)); }                            \
  int __ccl_bid_fix##SFX##si(T x) { int n, ok; ccl_u64 m = ccl_dec_trunc64(K, BITS(x), &n, &ok);                    \
    return !ok ? (int) 0x80000000u : n ? (m <= 0x80000000u ? (int) -(long) m : (int) 0x80000000u) : (m <= 0x7fffffffu ? (int) m : (int) 0x80000000u); } \
  unsigned __ccl_bid_fixuns##SFX##si(T x) { int n, ok; ccl_u64 m = ccl_dec_trunc64(K, BITS(x), &n, &ok);           \
    return !ok || n || m > 0xffffffffu ? 0 : (unsigned) m; }                                                        \
  long __ccl_bid_fix##SFX##di(T x) { int n, ok; ccl_u64 m = ccl_dec_trunc64(K, BITS(x), &n, &ok);                   \
    return !ok ? (long) 0x8000000000000000ul : n ? (m <= 0x8000000000000000ul ? (long) (0 - m) : (long) 0x8000000000000000ul) \
               : (m <= 0x7ffffffffffffffful ? (long) m : (long) 0x8000000000000000ul); }                          \
  ccl_u64 __ccl_bid_fixuns##SFX##di(T x) { int n, ok; ccl_u64 m = ccl_dec_trunc64(K, BITS(x), &n, &ok);             \
    return !ok || n ? 0 : m; }
CCL_ARITH(0, _Decimal32, sd, ccl_sd_bits, ccl_sd_of)
CCL_ARITH(1, _Decimal64, dd, ccl_dd_bits, ccl_dd_of)
CCL_ARITH(2, _Decimal128, td, ccl_td_bits, ccl_td_of)
/* between the decimal kinds */
_Decimal64 __ccl_bid_extendsddd2(_Decimal32 x) { return ccl_dd_of(ccl_dec_conv(0, 1, ccl_sd_bits(x))); }
_Decimal128 __ccl_bid_extendsdtd2(_Decimal32 x) { return ccl_td_of(ccl_dec_conv(0, 2, ccl_sd_bits(x))); }
_Decimal128 __ccl_bid_extendddtd2(_Decimal64 x) { return ccl_td_of(ccl_dec_conv(1, 2, ccl_dd_bits(x))); }
_Decimal32 __ccl_bid_truncddsd2(_Decimal64 x) { return ccl_sd_of(ccl_dec_conv(1, 0, ccl_dd_bits(x))); }
_Decimal32 __ccl_bid_trunctdsd2(_Decimal128 x) { return ccl_sd_of(ccl_dec_conv(2, 0, ccl_td_bits(x))); }
_Decimal64 __ccl_bid_trunctddd2(_Decimal128 x) { return ccl_dd_of(ccl_dec_conv(2, 1, ccl_td_bits(x))); }
/* from a binary format, `extend' or `trunc' by the formats' widths as libgcc names them; the quad's bits in a _Decimal128 */
_Decimal32 __ccl_bid_extendsfsd(float v) { return ccl_sd_of(ccl_bin_to_dec(0, 0, ccl_sf_bits(v))); }
_Decimal64 __ccl_bid_extendsfdd(float v) { return ccl_dd_of(ccl_bin_to_dec(0, 1, ccl_sf_bits(v))); }
_Decimal128 __ccl_bid_extendsftd(float v) { return ccl_td_of(ccl_bin_to_dec(0, 2, ccl_sf_bits(v))); }
_Decimal32 __ccl_bid_truncdfsd(double v) { return ccl_sd_of(ccl_bin_to_dec(1, 0, ccl_df_bits(v))); }
_Decimal64 __ccl_bid_extenddfdd(double v) { return ccl_dd_of(ccl_bin_to_dec(1, 1, ccl_df_bits(v))); }
_Decimal128 __ccl_bid_extenddftd(double v) { return ccl_td_of(ccl_bin_to_dec(1, 2, ccl_df_bits(v))); }
_Decimal32 __ccl_bid_truncxfsd(long double v) { return ccl_sd_of(ccl_bin_to_dec(2, 0, ccl_xf_bits(v))); }
_Decimal64 __ccl_bid_truncxfdd(long double v) { return ccl_dd_of(ccl_bin_to_dec(2, 1, ccl_xf_bits(v))); }
_Decimal128 __ccl_bid_extendxftd(long double v) { return ccl_td_of(ccl_bin_to_dec(2, 2, ccl_xf_bits(v))); }
_Decimal32 __ccl_bid_trunctfsd(_Decimal128 v) { return ccl_sd_of(ccl_bin_to_dec(3, 0, ccl_td_bits(v))); }
_Decimal64 __ccl_bid_trunctfdd(_Decimal128 v) { return ccl_dd_of(ccl_bin_to_dec(3, 1, ccl_td_bits(v))); }
_Decimal128 __ccl_bid_extendtftd(_Decimal128 v) { return ccl_td_of(ccl_bin_to_dec(3, 2, ccl_td_bits(v))); }
/* to a binary format */
float __ccl_bid_truncsdsf(_Decimal32 x) { return ccl_sf_of(ccl_dec_to_bin(0, 0, ccl_sd_bits(x))); }
double __ccl_bid_extendsddf(_Decimal32 x) { return ccl_df_of(ccl_dec_to_bin(0, 1, ccl_sd_bits(x))); }
long double __ccl_bid_extendsdxf(_Decimal32 x) { return ccl_xf_of(ccl_dec_to_bin(0, 2, ccl_sd_bits(x))); }
_Decimal128 __ccl_bid_extendsdtf(_Decimal32 x) { return ccl_td_of(ccl_dec_to_bin(0, 3, ccl_sd_bits(x))); }
float __ccl_bid_truncddsf(_Decimal64 x) { return ccl_sf_of(ccl_dec_to_bin(1, 0, ccl_dd_bits(x))); }
double __ccl_bid_truncdddf(_Decimal64 x) { return ccl_df_of(ccl_dec_to_bin(1, 1, ccl_dd_bits(x))); }
long double __ccl_bid_extendddxf(_Decimal64 x) { return ccl_xf_of(ccl_dec_to_bin(1, 2, ccl_dd_bits(x))); }
_Decimal128 __ccl_bid_extendddtf(_Decimal64 x) { return ccl_td_of(ccl_dec_to_bin(1, 3, ccl_dd_bits(x))); }
float __ccl_bid_trunctdsf(_Decimal128 x) { return ccl_sf_of(ccl_dec_to_bin(2, 0, ccl_td_bits(x))); }
double __ccl_bid_trunctddf(_Decimal128 x) { return ccl_df_of(ccl_dec_to_bin(2, 1, ccl_td_bits(x))); }
long double __ccl_bid_trunctdxf(_Decimal128 x) { return ccl_xf_of(ccl_dec_to_bin(2, 2, ccl_td_bits(x))); }
_Decimal128 __ccl_bid_trunctdtf(_Decimal128 x) { return ccl_td_of(ccl_dec_to_bin(2, 3, ccl_td_bits(x))); }

/* A 128-BIT INTEGER (0.137), libgcc has none of these: to a decimal rounded once; from one toward zero (a value past the
   integer's range has no defined result: the bits kept, a NaN or an infinity zero) */
_Decimal32 __ccl_bid_floattisd(__int128 i) { return ccl_sd_of(ccl_dec_round128(0, i < 0, i < 0 ? -(ccl_u128) i : (ccl_u128) i, 0, 0)); }
_Decimal64 __ccl_bid_floattidd(__int128 i) { return ccl_dd_of(ccl_dec_round128(1, i < 0, i < 0 ? -(ccl_u128) i : (ccl_u128) i, 0, 0)); }
_Decimal128 __ccl_bid_floattitd(__int128 i) { return ccl_td_of(ccl_dec_round128(2, i < 0, i < 0 ? -(ccl_u128) i : (ccl_u128) i, 0, 0)); }
_Decimal32 __ccl_bid_floatunstisd(ccl_u128 i) { return ccl_sd_of(ccl_dec_round128(0, 0, i, 0, 0)); }
_Decimal64 __ccl_bid_floatunstidd(ccl_u128 i) { return ccl_dd_of(ccl_dec_round128(1, 0, i, 0, 0)); }
_Decimal128 __ccl_bid_floatunstitd(ccl_u128 i) { return ccl_td_of(ccl_dec_round128(2, 0, i, 0, 0)); }
static ccl_u128 ccl_dec_trunc128(int k, ccl_u128 b, int *neg) {
  ccl_u128 c;
  int e;
  if (ccl_dec_get(k, b, neg, &e, &c) != 0) return 0;
  if (e >= 0) { while (e-- > 0) c *= 10; return c; }
  if (e < -39) return 0;
  while (e++ < 0) c /= 10;
  return c;
}
__int128 __ccl_bid_fixsdti(_Decimal32 d) { int n; ccl_u128 u = ccl_dec_trunc128(0, ccl_sd_bits(d), &n); return n ? -(__int128) u : (__int128) u; }
__int128 __ccl_bid_fixddti(_Decimal64 d) { int n; ccl_u128 u = ccl_dec_trunc128(1, ccl_dd_bits(d), &n); return n ? -(__int128) u : (__int128) u; }
__int128 __ccl_bid_fixtdti(_Decimal128 d) { int n; ccl_u128 u = ccl_dec_trunc128(2, ccl_td_bits(d), &n); return n ? -(__int128) u : (__int128) u; }
ccl_u128 __ccl_bid_fixunssdti(_Decimal32 d) { int n; return ccl_dec_trunc128(0, ccl_sd_bits(d), &n); }
ccl_u128 __ccl_bid_fixunsddti(_Decimal64 d) { int n; return ccl_dec_trunc128(1, ccl_dd_bits(d), &n); }
ccl_u128 __ccl_bid_fixunstdti(_Decimal128 d) { int n; return ccl_dec_trunc128(2, ccl_td_bits(d), &n); }

/* _BitInt(N) PAST 128 BITS (0.160): its limbs, 64 bits each, the least first, `prec' its width, negative for a signed one, as
   libgcc's own _BitInt conversions take them (libgcc 13 has none). To a decimal: the magnitude divided by ten while it passes
   128 bits, the digits taken off its sticky part, then the one rounding; from a decimal: the coefficient scaled into the
   limbs, toward zero, the bits past the width dropped. The bits past the width in the last limb are taken as the value's own
   extension. */
static int ccl_bi_limbs(int prec) { int b = prec < 0 ? -prec : prec; return (b + 63) / 64; }
static int ccl_bi_load(const ccl_u64 *p, int prec, ccl_u64 *m, int n) {
  int b = prec < 0 ? -prec : prec, neg = 0, i, top = b - 64 * (n - 1);
  for (i = 0; i < n; i++) m[i] = p[i];
  if (top < 64) { ccl_u64 mask = ((ccl_u64) 1 << top) - 1;
    if (prec < 0 && ((m[n - 1] >> (top - 1)) & 1)) m[n - 1] |= ~mask; else m[n - 1] &= mask; }
  if (prec < 0 && (m[n - 1] >> 63)) { unsigned c = 1; neg = 1;
    for (i = 0; i < n; i++) { ccl_u64 x = ~m[i] + c; c = (c && x == 0); m[i] = x; } }
  return neg;
}
static unsigned ccl_bi_div10(ccl_u64 *m, int n) {
  ccl_u128 r = 0; int i;
  for (i = n - 1; i >= 0; i--) { ccl_u128 cur = (r << 64) | m[i]; m[i] = (ccl_u64) (cur / 10); r = cur % 10; }
  return (unsigned) r;
}
static int ccl_bi_wide(const ccl_u64 *m, int n) { int i; for (i = 2; i < n; i++) if (m[i]) return 1; return 0; }
static ccl_u128 ccl_bi_to_dec(int k, const ccl_u64 *p, int prec) {
  int n = ccl_bi_limbs(prec), e = 0, sticky = 0;
  ccl_u64 m[n];
  int neg = ccl_bi_load(p, prec, m, n);
  while (ccl_bi_wide(m, n)) { sticky |= ccl_bi_div10(m, n) != 0; e++; }
  return ccl_dec_round128(k, neg, (ccl_u128) m[0] | (n > 1 ? (ccl_u128) m[1] << 64 : 0), e, sticky);
}
_Decimal32 __ccl_bid_floatbitintsd(const ccl_u64 *p, int prec) { return ccl_sd_of(ccl_bi_to_dec(0, p, prec)); }
_Decimal64 __ccl_bid_floatbitintdd(const ccl_u64 *p, int prec) { return ccl_dd_of(ccl_bi_to_dec(1, p, prec)); }
_Decimal128 __ccl_bid_floatbitinttd(const ccl_u64 *p, int prec) { return ccl_td_of(ccl_bi_to_dec(2, p, prec)); }
static void ccl_bi_store(int k, ccl_u64 *r, int prec, ccl_u128 b) {
  int n = ccl_bi_limbs(prec), i, e, neg, cls;
  ccl_u128 c;
  cls = ccl_dec_get(k, b, &neg, &e, &c);
  for (i = 0; i < n; i++) r[i] = 0;
  if (cls != 0) return;
  while (e < 0 && c != 0) { c /= 10; e++; }
  r[0] = (ccl_u64) c; if (n > 1) r[1] = (ccl_u64) (c >> 64);
  while (c != 0 && e-- > 0) { ccl_u128 carry = 0;
    for (i = 0; i < n; i++) { ccl_u128 cur = (ccl_u128) r[i] * 10 + carry; r[i] = (ccl_u64) cur; carry = cur >> 64; } }
  if (neg) { unsigned c1 = 1; for (i = 0; i < n; i++) { ccl_u64 v = ~r[i] + c1; c1 = (c1 && v == 0); r[i] = v; } }
}
void __ccl_bid_fixsdbitint(ccl_u64 *r, int prec, _Decimal32 d) { ccl_bi_store(0, r, prec, ccl_sd_bits(d)); }
void __ccl_bid_fixddbitint(ccl_u64 *r, int prec, _Decimal64 d) { ccl_bi_store(1, r, prec, ccl_dd_bits(d)); }
void __ccl_bid_fixtdbitint(ccl_u64 *r, int prec, _Decimal128 d) { ccl_bi_store(2, r, prec, ccl_td_bits(d)); }
