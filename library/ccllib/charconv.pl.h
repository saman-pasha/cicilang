/* what <charconv.pl> needs (phase 2): the result structs, the format and error names, and helpers for the macros.
   A result's `pos' is the offset of the first character not written (to_chars) or not read (from_chars): C++'s
   result holds a pointer there, and ccllib keeps the offset, since the safe part will not return a stored borrow.
   A write that does not fit gives value_too_large and the whole room's offset, as C++'s gives `last' (1.6.4). */
#ifndef _CICILANG_CCLLIB_CHARCONV_PL_H
#define _CICILANG_CCLLIB_CHARCONV_PL_H
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <math.h>

typedef struct { size_t pos; int ec; } to_chars_result;
typedef struct { size_t pos; int ec; } from_chars_result;
typedef enum { chars_scientific, chars_fixed, chars_hex, chars_general } chars_format;
enum { ccllib_errc_value_too_large = 1, ccllib_errc_invalid_argument = 2, ccllib_errc_result_out_of_range = 3 };

/* the styles of the floating helpers: 0 general, 1 fixed, 2 scientific, 3 hex, 4 the plain form of no format */
static inline to_chars_result ccllib_charconv_put(char *f, char *l, const char *b, size_t n) {
    to_chars_result r;
    if ((size_t)(l - f) < n) { r.pos = (size_t)(l - f); r.ec = ccllib_errc_value_too_large; return r; }
    if (n) memcpy(f, b, n);
    r.pos = n; r.ec = 0;
    return r;
}

/* the text that a count of digits and an exponent read back as: a double's, or a float's by strtof */
static inline double ccllib_charconv_read(const char *dig, int n, int x, int isf) {
    char t[48];
    snprintf(t, sizeof t, "%.*se%d", n, dig, x - (n - 1));
    return isf ? (double)strtof(t, 0) : strtod(t, 0);
}

/* THE SHORTEST DIGITS of v, finite and > 0, as C++17's to_chars has them (the fewest significant digits whose text
   reads back as v, the nearer text where two of one count do; Ryu's answer, libc++'s): at each count, snprintf's
   correctly rounded text, or its neighbour one unit away in its last digit on v's other side -- at a power of two the
   interval below v is half the one above, and the nearest text of a count may lie outside it while the neighbour lies
   inside (46 of the 2098 powers of two of a double). The digits into dig, the exponent of the first into *x10 */
static inline int ccllib_charconv_shortest(double v, int isf, char *dig, int *x10) {
    char b[40];
    int maxp = isf ? 8 : 16;
    for (int p = 0; p <= maxp; p++) {
        snprintf(b, sizeof b, "%.*e", p, v);
        char *e = strchr(b, 'e');
        int x = atoi(e + 1), n = 0;
        for (char *q = b; q < e; q++) if (*q != '.') dig[n++] = *q;
        dig[n] = 0;
        double c = ccllib_charconv_read(dig, n, x, isf);
        if (c == v) { *x10 = x; return n; }
        unsigned long long m = strtoull(dig, 0, 10), pw = 1, m2;
        int x2 = x;
        for (int i = 1; i < n; i++) pw *= 10;
        if (c > v) { m2 = m - 1; if (m2 < pw) { m2 = pw * 10 - 1; x2 = x - 1; } }
        else { m2 = m + 1; if (m2 >= pw * 10) continue; }
        char d2[24];
        if (snprintf(d2, sizeof d2, "%llu", m2) == n && ccllib_charconv_read(d2, n, x2, isf) == v) {
            memcpy(dig, d2, (size_t)n + 1); *x10 = x2; return n;
        }
    }
    snprintf(b, sizeof b, "%.*e", maxp + 1, v);
    { char *e = strchr(b, 'e'); int n = 0; *x10 = atoi(e + 1); for (char *q = b; q < e; q++) if (*q != '.') dig[n++] = *q; dig[n] = 0; return n; }
}

/* the digits laid out: scientific d[.ddd]e+XX, fixed */
static inline int ccllib_charconv_sci_text(char *o, const char *dig, int n, int x) {
    int k = 0;
    o[k++] = dig[0];
    if (n > 1) { o[k++] = '.'; memcpy(o + k, dig + 1, (size_t)n - 1); k += n - 1; }
    k += sprintf(o + k, "e%c%02d", x < 0 ? '-' : '+', x < 0 ? -x : x);
    return k;
}
static inline int ccllib_charconv_fixed_text(char *o, const char *dig, int n, int x) {
    int k = 0;
    if (x < 0) {
        o[k++] = '0'; o[k++] = '.';
        for (int i = 0; i < -x - 1; i++) o[k++] = '0';
        memcpy(o + k, dig, (size_t)n); k += n;
    } else if (x >= n - 1) {
        memcpy(o + k, dig, (size_t)n); k += n;
        for (int i = 0; i < x - (n - 1); i++) o[k++] = '0';
    } else {
        memcpy(o + k, dig, (size_t)x + 1); k += x + 1;
        o[k++] = '.';
        memcpy(o + k, dig + x + 1, (size_t)(n - x - 1)); k += n - x - 1;
    }
    o[k] = 0;
    return k;
}

/* a NaN's and an infinity's words, libc++'s (MSVC's): nan, -nan(ind) for a negative quiet NaN of no payload, -nan for
   one of a payload, nan(snan) and -nan(snan) for a signaling NaN; inf, -inf */
static inline int ccllib_charconv_special(char *o, int neg, int nan, int quiet, int payload) {
    if (!nan) return sprintf(o, "%sinf", neg ? "-" : "");
    if (!quiet) return sprintf(o, "%snan(snan)", neg ? "-" : "");
    if (neg) return sprintf(o, payload ? "-nan" : "-nan(ind)");
    return sprintf(o, "nan");
}

/* a hex text: %a without its 0x; a float's denormal as a float has it, 0.xxxxxxp-126 */
static inline int ccllib_charconv_hex_text(char *o, double v, int isf) {
    char b[64]; int k = 0;
    if (isf && v != 0 && fabs(v) < 1.1754943508222875e-38) {
        float fv = (float)v; uint32_t u; memcpy(&u, &fv, 4);
        uint32_t man = (u & 0x7fffffu) << 1;
        int nd = 6;
        while (nd > 0 && (man & 0xf) == 0) { man >>= 4; nd--; }
        if (u >> 31) o[k++] = '-';
        o[k++] = '0';
        if (nd) { o[k++] = '.'; k += sprintf(o + k, "%0*x", nd, man); }
        k += sprintf(o + k, "p-126");
        return k;
    }
    int n = snprintf(b, sizeof b, "%a", v);
    for (int i = 0; i < n; i++) {
        if ((b[i] == 'x' || b[i] == 'X') && i > 0 && b[i - 1] == '0') { k--; continue; }
        o[k++] = b[i];
    }
    o[k] = 0;
    return k;
}

/* to_chars of a floating value with no precision: the shortest text of the style (libc++'s): fixed, the least decimals
   that read back, an integer of 2^53 or more (2^24, a float's) its exact digits; scientific, the shortest digits;
   general, the shortest digits fixed where -4 <= X < 6, else scientific (P is 6 where no precision is given); the plain
   form, the shorter of fixed and scientific, fixed on a tie; hex, %a without 0x */
static inline to_chars_result ccllib_charconv_float_text(char *f, char *l, double v, int isf, int neg, int style) {
    char o[1200];
    char dig[24];
    int k = 0, x = 0, n;
    if (neg) o[k++] = '-';
    if (style == 3) { k += ccllib_charconv_hex_text(o + k, v, isf); return ccllib_charconv_put(f, l, o, (size_t)k); }
    if (v == 0) { dig[0] = '0'; dig[1] = 0; n = 1; x = 0; }
    else n = ccllib_charconv_shortest(v, isf, dig, &x);
    char fx[1200], sc[48];
    int nf, ns = ccllib_charconv_sci_text(sc, dig, n, x);
    if (v >= (isf ? 16777216.0 : 9007199254740992.0)) nf = snprintf(fx, sizeof fx, "%.0f", v);
    else nf = ccllib_charconv_fixed_text(fx, dig, n, x);
    const char *t; int nt;
    if (style == 1) { t = fx; nt = nf; }
    else if (style == 2) { t = sc; nt = ns; }
    else if (style == 0) { if (x >= -4 && x < 6) { t = fx; nt = nf; } else { t = sc; nt = ns; } }
    else { if (nf <= ns) { t = fx; nt = nf; } else { t = sc; nt = ns; } }
    memcpy(o + k, t, (size_t)nt); k += nt;
    return ccllib_charconv_put(f, l, o, (size_t)k);
}
static inline to_chars_result ccllib_charconv_to_d(char *f, char *l, double v, int style) {
    char o[24]; uint64_t u; memcpy(&u, &v, 8);
    int neg = (int)(u >> 63);
    if (isnan(v) || isinf(v)) {
        int k = ccllib_charconv_special(o, neg, isnan(v), (int)((u >> 51) & 1), (u & 0x7ffffffffffffULL) != 0);
        return ccllib_charconv_put(f, l, o, (size_t)k);
    }
    return ccllib_charconv_float_text(f, l, neg ? -v : v, 0, neg, style);
}
static inline to_chars_result ccllib_charconv_to_f(char *f, char *l, float v, int style) {
    char o[24]; uint32_t u; memcpy(&u, &v, 4);
    int neg = (int)(u >> 31);
    if ((u & 0x7f800000u) == 0x7f800000u) {
        int k = ccllib_charconv_special(o, neg, (u & 0x7fffffu) != 0, (int)((u >> 22) & 1), (u & 0x3fffffu) != 0);
        return ccllib_charconv_put(f, l, o, (size_t)k);
    }
    return ccllib_charconv_float_text(f, l, neg ? -(double)v : (double)v, 1, neg, style);
}

/* to_chars with a precision: printf's text of the style at that precision, as C++ writes it (hex without 0x); a NaN's and
   an infinity's words as with no precision */
static inline to_chars_result ccllib_charconv_prec_text(char *f, char *l, double v, int style, int prec) {
    char o[1400], b[1400];
    int n, k = 0;
    if (prec < 0) prec = 6;
    if (style == 1) n = snprintf(b, sizeof b, "%.*f", prec, v);
    else if (style == 2) n = snprintf(b, sizeof b, "%.*e", prec, v);
    else if (style == 3) n = snprintf(b, sizeof b, "%.*a", prec, v);
    else n = snprintf(b, sizeof b, "%.*g", prec, v);
    if (n < 0 || n >= (int)sizeof b) { to_chars_result r = { (size_t)(l - f), ccllib_errc_value_too_large }; return r; }
    for (int i = 0; i < n; i++) {
        if (style == 3 && (b[i] == 'x' || b[i] == 'X') && i > 0 && b[i - 1] == '0') { k--; continue; }
        o[k++] = b[i];
    }
    return ccllib_charconv_put(f, l, o, (size_t)k);
}
static inline to_chars_result ccllib_charconv_to_prec_d(char *f, char *l, double v, int style, int prec) {
    if (isnan(v) || isinf(v)) return ccllib_charconv_to_d(f, l, v, style);
    return ccllib_charconv_prec_text(f, l, v, style, prec);
}
static inline to_chars_result ccllib_charconv_to_prec_f(char *f, char *l, float v, int style, int prec) {
    if (isnan(v) || isinf(v)) return ccllib_charconv_to_f(f, l, v, style);
    return ccllib_charconv_prec_text(f, l, (double)v, style, prec);
}

/* the integers written: a signed one and an unsigned one */
static inline to_chars_result ccllib_charconv_to_ull(char *f, char *l, unsigned long long v, int base) {
    char b[72], o[72];
    int n = 0;
    do { int d = (int)(v % (unsigned)base); b[n++] = (char)(d < 10 ? '0' + d : 'a' + d - 10); v /= (unsigned)base; } while (v);
    for (int i = 0; i < n; i++) o[i] = b[n - 1 - i];
    return ccllib_charconv_put(f, l, o, (size_t)n);
}
static inline to_chars_result ccllib_charconv_to_ll(char *f, char *l, long long v, int base) {
    char b[72], o[72];
    int n = 0, neg = v < 0;
    unsigned long long u = neg ? (unsigned long long)(-(v + 1)) + 1 : (unsigned long long)v;
    do { int d = (int)(u % (unsigned)base); b[n++] = (char)(d < 10 ? '0' + d : 'a' + d - 10); u /= (unsigned)base; } while (u);
    int k = 0;
    if (neg) o[k++] = '-';
    for (int i = 0; i < n; i++) o[k++] = b[n - 1 - i];
    return ccllib_charconv_put(f, l, o, (size_t)k);
}
/* FROM_CHARS OF A FLOATING NUMBER (1.6.4): the characters of [f, l) that the style takes, after an optional '-' --
   inf, infinity, nan and nan(chars) in each; else a mantissa of digits and a point, hex digits for hex, and its exponent:
   none for fixed, needed for scientific, taken where its digits follow for general and hex. C++'s pattern
   ([charconv.from.chars]): no white space, no '+', no 0x before hex digits, which C++'s hex takes as given. 0 where no
   number begins; *special where strtod reads the word */
static inline size_t ccllib_charconv_scan(const char *f, const char *l, int style, int *special) {
    size_t n = (size_t)(l - f), i = 0, d = 0;
    int hex = style == 3;
    *special = 0;
    if (i < n && f[i] == '-') i++;
    if (i < n && (f[i] == 'i' || f[i] == 'I' || f[i] == 'n' || f[i] == 'N')) { *special = 1; return n; }
#define CCLLIB_CC_DIGIT(c) ((c) >= '0' && (c) <= '9' || hex && (((c) >= 'a' && (c) <= 'f') || ((c) >= 'A' && (c) <= 'F')))
    while (i < n && CCLLIB_CC_DIGIT(f[i])) { i++; d++; }
    if (i < n && f[i] == '.') { i++; while (i < n && CCLLIB_CC_DIGIT(f[i])) { i++; d++; } }
#undef CCLLIB_CC_DIGIT
    if (d == 0) return 0;
    if (style != 1 && i < n && (f[i] == (hex ? 'p' : 'e') || f[i] == (hex ? 'P' : 'E'))) {
        size_t j = i + 1, j0;
        if (j < n && (f[j] == '+' || f[j] == '-')) j++;
        j0 = j;
        while (j < n && f[j] >= '0' && f[j] <= '9') j++;
        if (j > j0) return j;
    }
    return style == 2 ? 0 : i;
}
/* the value of the characters: strtod's, strtof's for a float and strtold's for a long double, each rounded once; a
   range error where the value is no finite non-zero one of the type -- a denormal is none, as C++'s -- leaves the
   object, and the offset is the pattern's end */
static inline from_chars_result ccllib_charconv_from_fp(const char *f, const char *l, void *out, int width, int style) {
    from_chars_result r = { 0, ccllib_errc_invalid_argument };
    int special, neg;
    size_t k = f < l ? ccllib_charconv_scan(f, l, style, &special) : 0, pre;
    if (k == 0) return r;
    neg = f[0] == '-';
    pre = style == 3 && !special ? 2 : 0;
    char sb[256];
    own char *heap = 0;
    char *b = sb;
    if (k + pre + 1 > sizeof sb) { heap = (char *)malloc(k + pre + 1); if (!heap) abort(); b = heap; }
    size_t m = 0;
    if (neg) b[m++] = '-';
    if (pre) { b[m++] = '0'; b[m++] = 'x'; }
    memcpy(b + m, f + neg, k - (size_t)neg); m += k - (size_t)neg; b[m] = 0;
    char *e;
    errno = 0;
    long double vl = 0; double vd = 0; float vf = 0;
    if (width == 4) vf = strtof(b, &e); else if (width == 8) vd = strtod(b, &e); else vl = strtold(b, &e);
    size_t used = (size_t)(e - b);
    int range = errno == ERANGE;
    free(heap);
    if (used <= pre + (size_t)neg) return r;
    r.pos = used - pre; r.ec = 0;
    if (range) {
        int zero_or_huge = width == 4 ? (vf == 0 || isinf(vf)) : width == 8 ? (vd == 0 || isinf(vd)) : (vl == 0 || isinf(vl));
        if (zero_or_huge) { r.ec = ccllib_errc_result_out_of_range; return r; }
    }
    if (width == 4) *(float *)out = vf; else if (width == 8) *(double *)out = vd; else *(long double *)out = vl;
    return r;
}
/* the integers read: a signed one and an unsigned one, base 2 to 36, a '-' of a signed type alone */
static inline from_chars_result ccllib_charconv_parse_int_result(const char *f, const char *l, int base, int allow_sign,
                                                                unsigned long long *mag, int *neg) {
    size_t i = 0, j = (size_t)(l - f);
    int n = 0;
    unsigned long long u = 0;
    *neg = 0;
    if (i < j && f[i] == '-') {
        if (!allow_sign) return (from_chars_result){ 0, ccllib_errc_invalid_argument };
        *neg = 1;
        i++;
    }
    int over = 0;
    while (i < j) {
        int d;
        char c = f[i];
        if (c >= '0' && c <= '9') d = c - '0';
        else if (c >= 'a' && c <= 'z') d = c - 'a' + 10;
        else if (c >= 'A' && c <= 'Z') d = c - 'A' + 10;
        else break;
        if (d >= base) break;
        if (!over && u > (18446744073709551615ULL - (unsigned)d) / (unsigned)base) over = 1;
        else if (!over) u = u * (unsigned)base + (unsigned)d;
        n++;
        i++;
    }
    if (n == 0) return (from_chars_result){ 0, ccllib_errc_invalid_argument };
    if (over) return (from_chars_result){ i, ccllib_errc_result_out_of_range };
    *mag = u;
    return (from_chars_result){ i, 0 };
}

static inline long long ccllib_charconv_smin(int w) {
    return w == 1 ? -128LL : w == 2 ? -32768LL : w == 4 ? (long long)INT32_MIN : (long long)INT64_MIN;
}
static inline long long ccllib_charconv_smax(int w) {
    return w == 1 ? 127LL : w == 2 ? 32767LL : w == 4 ? (long long)INT32_MAX : (long long)INT64_MAX;
}
static inline unsigned long long ccllib_charconv_umax(int w) {
    return w == 1 ? 255ULL : w == 2 ? 65535ULL : w == 4 ? (unsigned long long)UINT32_MAX : 18446744073709551615ULL;
}

static inline from_chars_result ccllib_charconv_from_signed(const char *f, const char *l, void *out, int base, int width) {
    unsigned long long u;
    int neg;
    from_chars_result r = ccllib_charconv_parse_int_result(f, l, base, 1, &u, &neg);
    long long v;
    if (r.ec) return r;
    if (neg) {
        unsigned long long lim = (unsigned long long)(-(ccllib_charconv_smin(width) + 1)) + 1;
        if (u > lim) return (from_chars_result){ r.pos, ccllib_errc_result_out_of_range };
        v = -(long long)(u - 1) - 1;
    } else {
        if (u > (unsigned long long)ccllib_charconv_smax(width)) return (from_chars_result){ r.pos, ccllib_errc_result_out_of_range };
        v = (long long)u;
    }
    if (width == 1) *(int8_t *)out = (int8_t)v;
    else if (width == 2) *(int16_t *)out = (int16_t)v;
    else if (width == 4) *(int32_t *)out = (int32_t)v;
    else *(int64_t *)out = (int64_t)v;
    return r;
}
static inline from_chars_result ccllib_charconv_from_unsigned(const char *f, const char *l, void *out, int base, int width) {
    unsigned long long u;
    int neg;
    from_chars_result r = ccllib_charconv_parse_int_result(f, l, base, 0, &u, &neg);
    if (r.ec) return r;
    if (neg || u > ccllib_charconv_umax(width)) return (from_chars_result){ r.pos, ccllib_errc_result_out_of_range };
    if (width == 1) *(uint8_t *)out = (uint8_t)u;
    else if (width == 2) *(uint16_t *)out = (uint16_t)u;
    else if (width == 4) *(uint32_t *)out = (uint32_t)u;
    else *(uint64_t *)out = (uint64_t)u;
    return r;
}
#endif
