/* C23's <float.h>, <limits.h>, <stdarg.h> and <stdatomic.h> (0.194): the signaling NaNs, INFINITY and NAN, the normalized
   maxima, FLT_ROUNDS the current rounding direction, the widths, char8_t's atomic type, the binary formats, va_start of
   one argument */
#include <stdio.h>
#include <string.h>
#include <float.h>
#include <limits.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <fenv.h>
static void bits(const char *n, const void *p, int k) { const unsigned char *q = p; printf("%s ", n); for (int x = k - 1; x >= 0; x--) printf("%02x", q[x]); printf("\n"); }
/* a long double's NaN, the same on every machine: the quiet bit and the bit below it, by the format (x87's, a quad's, a double's) */
static void ldbits(const char *n, const long double *p) { const unsigned char *q = (const unsigned char *) p;
  int quiet = LDBL_MANT_DIG == 64 ? (q[7] >> 6) & 1 : LDBL_MANT_DIG == 113 ? (q[13] >> 7) & 1 : (q[6] >> 3) & 1;
  int next = LDBL_MANT_DIG == 64 ? (q[7] >> 5) & 1 : LDBL_MANT_DIG == 113 ? (q[13] >> 6) & 1 : (q[6] >> 2) & 1;
  printf("%s %d %d %d\n", n, *p != *p, quiet, next); }
double a = DBL_SNAN; float b = FLT_SNAN; long double c = LDBL_SNAN; double d = -DBL_SNAN;
double h = INFINITY; float i = NAN; double j = DBL_NORM_MAX;
int sum(int n, ...) { va_list ap; va_start(ap); int s = 0; for (int k = 0; k < n; k++) s += va_arg(ap, int); va_end(ap); return s; }
int main(void) {
  bits("a", &a, 8); bits("b", &b, 4); ldbits("c", &c); bits("d", &d, 8); bits("h", &h, 8); bits("i", &i, 4); bits("j", &j, 8);
  double la = DBL_SNAN; bits("la", &la, 8); float lb = FLT_SNAN; bits("lb", &lb, 4); long double lc = LDBL_SNAN; ldbits("lc", &lc);
  printf("rounds %d", FLT_ROUNDS); fesetround(FE_UPWARD); printf(" %d", FLT_ROUNDS); fesetround(FE_TOWARDZERO); printf(" %d", FLT_ROUNDS);
  fesetround(FE_DOWNWARD); printf(" %d", FLT_ROUNDS); fesetround(FE_TONEAREST); printf(" %d\n", FLT_ROUNDS);
  printf("%g %g %d\n", FLT_NORM_MAX, DBL_NORM_MAX, LDBL_NORM_MAX == LDBL_MAX);   /* a long double's maximum is the machine's: an x87's, a quad's, a double's on Apple's arm64 (0.248) */
  printf("widths %d %d %d %d %d %d\n", BOOL_WIDTH, CHAR_WIDTH, SHRT_WIDTH, INT_WIDTH, LONG_WIDTH, LLONG_WIDTH);
  printf("char8 %d %d\n", (int) sizeof(__CHAR8_TYPE__), ATOMIC_CHAR8_T_LOCK_FREE);
  atomic_char8_t a8 = 7; printf("a8 %d\n", (int) atomic_load(&a8));
  /* the 64-bit format's length modifier is its type's (0.225): `lb' where uint64_t is unsigned long, Linux's, `llb' where it
     is unsigned long long, a Mac's */
  printf("fmt %s %s %s\n", __UINT8_FMTb__, __UINT32_FMTB__, strcmp(__UINT64_FMTb__, _Generic((__UINT64_TYPE__) 0, unsigned long: "lb", unsigned long long: "llb", default: "?")) == 0 ? "the type's" : __UINT64_FMTb__);
  printf("sum %d\n", sum(3, 4, 5, 6));
  printf("bitint %d eval %d\n", BITINT_MAXWIDTH >= 128, FLT_EVAL_METHOD);
  return 0;
}
