/* clang's library builtins (1.6.47): __builtin_F is the C library's F with no declaration -- the allocation functions and
   abort, the memory and string functions, the printf and scanf families, the math functions of each shape; built as C
   and as C++, each line as clang's */
#include <stdarg.h>
static int formats(char *b, unsigned long n, const char *fmt, ...) {
  va_list ap; va_start(ap, fmt); int r = __builtin_vsnprintf(b, n, fmt, ap); va_end(ap); return r;
}
static volatile int one = 1;   /* a value that no fold takes, as argc is none here: the gates run it with arguments */
static int ended(int c) { char *p = (char *) __builtin_malloc(8); if (c > 5) __builtin_abort(); __builtin_free(p); return 1; }
int main(void) {
  char a[32], b[32];
  __builtin_strcpy(a, "hello");
  __builtin_strncpy(b, "world!", 5); b[5] = 0;
  __builtin_strcat(a, "-"); __builtin_strncat(a, b, 3);
  char *e = __builtin_stpcpy(b, "ab"); *e = 'c'; e[1] = 0;
  char *f = __builtin_stpncpy(b + 3, "xyz", 2); *f = 0;
  __builtin_printf("%s %s %d %d\n", a, b, __builtin_strcmp(a, b) > 0, __builtin_strncmp(a, "help", 3));
  __builtin_printf("%s %s %s %s\n", __builtin_strchr(a, 'l'), __builtin_strrchr(a, 'l'), __builtin_index(a, 'w'), __builtin_rindex(a, 'h'));
  __builtin_printf("%s %s %d %d\n", __builtin_strstr(a, "lo"), __builtin_strpbrk(a, "-w"), (int) __builtin_strspn(a, "hel"), (int) __builtin_strcspn(a, "-"));
  char z[4] = "abc"; __builtin_bzero(z, 2);
  __builtin_memmove(b + 1, b, 3); __builtin_memset(b, '=', 1);
  __builtin_printf("%d %d %d %d %s %d\n", z[0], z[2], __builtin_bcmp("ab", "ac", 2) != 0, *(char *) __builtin_memchr(a, 'o', 6), b, __builtin_memcmp(a, "hello", 5));
  char *d = __builtin_strdup(a); char *n = __builtin_strndup(a, 3);
  __builtin_printf("%s %s %d\n", d, n, (int) __builtin_strlen(d));
  __builtin_free(d); __builtin_free(n);
  int *m = (int *) __builtin_malloc(4 * sizeof(int)); int *c = (int *) __builtin_calloc(4, sizeof(int));
  m[0] = 7; m = (int *) __builtin_realloc(m, 8 * sizeof(int)); m[7] = c[3] + 1;
  __builtin_printf("%d %d %d\n", m[0], m[7], ended(one));
  __builtin_free(m); __builtin_free(c);
  char buf[32]; int x = 0; char w[8];
  __builtin_snprintf(buf, sizeof buf, "%d %s", 12, "ab");
  int k = __builtin_sscanf(buf, "%d %7s", &x, w);
  __builtin_sprintf(w, "%03d", formats(buf, sizeof buf, "%s+%d", "v", 9));
  __builtin_printf("%d %d %s %s\n", k, x, w, buf);
  double v = one + 1.75; float fl = (float) v; long double l = v; int q = 0, ex = 0; double ip = 0;
  __builtin_printf("%g %g %g %g %g\n", __builtin_ceil(v), __builtin_trunc(-v), __builtin_round(v), __builtin_roundeven(2.5), __builtin_rint(v));
  __builtin_printf("%g %g %g %g\n", __builtin_nearbyint(v), __builtin_fmin(v, 1.0), __builtin_fmax(v, 9.0), __builtin_fma(v, 2.0, 1.0));
  __builtin_printf("%g %d %g %g\n", __builtin_remquo(7.0, 2.0, &q), q, __builtin_nexttoward(1.0, 2.0L) - __builtin_nexttoward(1.0, 1.0L), __builtin_scalbln(v, 3L));
  __builtin_printf("%ld %lld %d %g %g\n", __builtin_lround(v), __builtin_llrint(v), __builtin_ilogb(v), __builtin_ldexp(v, 2), __builtin_scalbn(v, -1));
  __builtin_printf("%g %d %g %g\n", __builtin_frexp(v, &ex), ex, __builtin_modf(v, &ip), ip);
  __builtin_printf("%g %g %g %g %g\n", __builtin_fdim(v, 1.0), __builtin_hypot(3.0, 4.0), __builtin_cbrt(27.0), __builtin_fmod(v, 1.0), __builtin_sqrt(16));
  __builtin_printf("%g %g %g %g\n", (double) __builtin_floorf(fl), (double) __builtin_copysignf(fl, -1.0f), (double) __builtin_fabsf(-fl), __builtin_floor(v));
  __builtin_printf("%Lg %Lg %Lg %Lg\n", __builtin_floorl(l), __builtin_sqrtl(l * l), __builtin_fmal(l, 2.0L, 1.0L), __builtin_fminl(l, 0.5L));
  __builtin_printf("%g %g %g %g\n", __builtin_pow(2.0, 10.0), __builtin_exp2(3.0), __builtin_log2(8.0), __builtin_fabs(-v));
  __typeof__(__builtin_floorf(fl)) t = 2.5f; double r = one > 5 ? 1 : __builtin_floor(v);   /* a call's type is its prototype's result */
  __builtin_printf("%g %g %d %d\n", (double) t, r, (int) sizeof(__builtin_floorl(l)) >= 8, (int) sizeof(__builtin_strlen(a)));
  return 0;
}
