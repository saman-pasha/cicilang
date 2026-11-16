/* what <charconv.pl> needs (phase 2): the result structs, the format and error names, and helpers for the macros.
   A result's `pos' is the offset of the first character not written (to_chars) or not read (from_chars): C++'s
   result holds a pointer there, and ccllib keeps the offset, since the safe part will not return a stored borrow. */
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

static inline int ccllib_charconv_trim(char *b, int n, int style) {
    if (style == 0 || n <= 0) return n;
    if (style == 3) {
        char *q = b + (b[0] == '-' ? 1 : 0);
        if (q[0] == '0' && (q[1] == 'x' || q[1] == 'X')) {
            memmove(q, q + 2, strlen(q + 2) + 1);
            n -= 2;
        }
    }
    char *e = 0;
    if (style == 2) { e = strchr(b, 'e'); if (!e) e = strchr(b, 'E'); }
    else if (style == 3) { e = strchr(b, 'p'); if (!e) e = strchr(b, 'P'); }
    char *z = e ? e : b + n;
    while (z > b && z[-1] == '0') z--;
    if (z > b && z[-1] == '.') z--;
    if (e) {
        memmove(z, e, strlen(e) + 1);
        n = (int)(z - b) + (int)strlen(e);
    } else {
        *z = 0;
        n = (int)(z - b);
    }
    return n;
}

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

static inline from_chars_result ccllib_charconv_parse_double_result(const char *f, const char *l, double *v) {
    char b[256];
    size_t n;
    if (f >= l) return (from_chars_result){ 0, ccllib_errc_invalid_argument };
    if (*f == ' ' || *f == '\t' || *f == '\n' || *f == '\r' || *f == '\v' || *f == '\f' || *f == '+')
        return (from_chars_result){ 0, ccllib_errc_invalid_argument };
    n = (size_t)(l - f);
    if (n > sizeof b - 1) n = sizeof b - 1;
    memcpy(b, f, n);
    b[n] = 0;
    char *e;
    errno = 0;
    double d = strtod(b, &e);
    if (e == b) return (from_chars_result){ 0, ccllib_errc_invalid_argument };
    if (errno == ERANGE) return (from_chars_result){ 0, ccllib_errc_result_out_of_range };
    *v = d;
    return (from_chars_result){ (size_t)(e - b), 0 };
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

static inline to_chars_result ccllib_charconv_to_ll(char *f, char *l, long long v, int base) {
    char b[72];
    int n = 0, neg = 0;
    unsigned long long u;
    to_chars_result r;
    if (v < 0) { neg = 1; u = (unsigned long long)(-(v + 1)) + 1; } else u = (unsigned long long)v;
    do { int d = (int)(u % (unsigned)base); b[n++] = (char)(d < 10 ? '0' + d : 'a' + d - 10); u /= (unsigned)base; } while (u);
    if (neg) b[n++] = '-';
    if (l - f < n) { r.pos = 0; r.ec = ccllib_errc_value_too_large; }
    else { for (int i = 0; i < n; i++) f[i] = b[n - 1 - i]; r.pos = (size_t)n; r.ec = 0; }
    return r;
}
static inline to_chars_result ccllib_charconv_to_ull(char *f, char *l, unsigned long long v, int base) {
    char b[72];
    int n = 0;
    to_chars_result r;
    do { int d = (int)(v % (unsigned)base); b[n++] = (char)(d < 10 ? '0' + d : 'a' + d - 10); v /= (unsigned)base; } while (v);
    if (l - f < n) { r.pos = 0; r.ec = ccllib_errc_value_too_large; }
    else { for (int i = 0; i < n; i++) f[i] = b[n - 1 - i]; r.pos = (size_t)n; r.ec = 0; }
    return r;
}
static inline to_chars_result ccllib_charconv_to_d(char *f, char *l, double v, int style) {
    char b[512];
    int n = snprintf(b, sizeof b, style == 1 ? "%f" : style == 2 ? "%e" : style == 3 ? "%a" : "%.17g", v);
    to_chars_result r;
    if (n < 0 || n >= (int)sizeof b) { r.pos = 0; r.ec = ccllib_errc_value_too_large; return r; }
    n = ccllib_charconv_trim(b, n, style);
    if (l - f < n) { r.pos = 0; r.ec = ccllib_errc_value_too_large; }
    else { if (n) memcpy(f, b, (size_t)n); r.pos = (size_t)n; r.ec = 0; }
    return r;
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
static inline from_chars_result ccllib_charconv_from_double(const char *f, const char *l, void *out, int width) {
    double d;
    from_chars_result r = ccllib_charconv_parse_double_result(f, l, &d);
    if (r.ec) return r;
    if (width == 4) *(float *)out = (float)d;
    else if (width == 8) *(double *)out = d;
    else *(long double *)out = (long double)d;
    return r;
}
#endif
