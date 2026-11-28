/* clang's builtins of the frame's memory and of the complex functions (1.6.54): __builtin_alloca, glibc's alloca, and its
   _uninitialized and _with_align forms are LLVM's alloca, a borrow of the frame to the safe part; __builtin_creal, __builtin_cabsf, __builtin_cexp and kin are the C
   library's functions by their prototypes; built as C and as C++, each line as clang's */
#include <alloca.h>
#include <stdio.h>
#include <string.h>
static volatile int many = 10;   /* a value that no fold takes */
static int sum(int n) {
  int *a = (int *) alloca(n * sizeof(int));
  for (int i = 0; i < n; i++) a[i] = i;
  int s = 0;
  for (int i = 0; i < n; i++) s += a[i];
  return s;
}
static int longest(const char *const *ws, int n) {
  int best = 0;
  for (int i = 0; i < n; i++) {
    char *c = (char *) __builtin_alloca(strlen(ws[i]) + 1);   /* a block's alloca lives to the function's end */
    strcpy(c, ws[i]);
    if ((int) strlen(c) > best) best = (int) strlen(c);
  }
  return best;
}
int main(void) {
  char *p = (char *) alloca(16);
  strcpy(p, "frame");
  char *q = p + 2;
  const char *ws[] = { "a", "three", "seven77" };
  printf("%s %s %d %d %d\n", p, q, sum(many), sum(many * 10), longest(ws, 3));
  char *u3 = (char *) alloca(3); char *u4 = (char *) alloca(many + 3);   /* each aligned to 16, as clang's */
  printf("%d %d\n", (int) ((unsigned long) u3 % 16), (int) ((unsigned long) u4 % 16));
  char *a32 = (char *) __builtin_alloca_with_align(8, 256); char *un = (char *) __builtin_alloca_uninitialized(5); un[0] = 7;
  printf("%d %d %d\n", (int) ((unsigned long) a32 % 32), (int) ((unsigned long) un % 16), un[0]);
  double _Complex z = 3.0 + 4.0 * __builtin_complex(0.0, 1.0);
  float _Complex w = __builtin_complex(1.0f, 1.0f);
  long double _Complex v = __builtin_complex(1.0L, -2.0L);
  printf("%g %g %g %.4f %g\n", __builtin_creal(z), __builtin_cimag(z), __builtin_cabs(z), __builtin_carg(z), __builtin_cimag(__builtin_conj(z)));
  printf("%.4f %.4f %g %Lg %Lg\n", __builtin_cabsf(w), __builtin_cargf(w), __builtin_crealf(w), __builtin_creall(v), __builtin_cimagl(__builtin_conjl(v)));
  double _Complex e = __builtin_cexp(__builtin_complex(0.0, 0.0));
  double _Complex r = __builtin_csqrt(__builtin_complex(-4.0, 0.0));
  double _Complex pw = __builtin_cpow(z, __builtin_complex(2.0, 0.0));
  printf("%g %g %g %g %.1f %.1f\n", __builtin_creal(e), __builtin_cimag(e), __builtin_creal(r), __builtin_cimag(r), __builtin_creal(pw), __builtin_cimag(pw));
  return 0;
}
