/* Infinities and NaNs in floating constants, folded as clang folds them: a literal past the largest double is an
   infinity (a long double literal keeps its double's value), the builtins behind INFINITY, HUGE_VAL and NAN fold in a
   global's initializer, an invalid operation is the quiet NaN, and a negation keeps a NaN's sign. */
#include <math.h>
#include <stdio.h>

double big = 1e999, nbig = -1e999, bigsum = 1e999 - 1e999, nbigsum = -(1e999 - 1e999), bigzero = 1e999 * 0.0;
float bigf = 1e999f, fnan = NAN, fnnan = -NAN;
double dinf = INFINITY, dninf = -INFINITY, huge = HUGE_VAL, dnan = NAN, dnnan = -NAN, zz = 0.0 / 0.0;
long double linf = __builtin_infl(), lnan = __builtin_nanl(""), lnnan = -__builtin_nanl("");
double cnan = (double) NAN, quot = 1.0 / 1e999, nquot = -1.0 / 1e999;

int main(void) {
  double l = 1e999;
  printf("%g %g %g %g %g\n", big, nbig, bigsum, nbigsum, bigzero);
  printf("%g %g %g\n", (double) bigf, (double) fnan, (double) fnnan);
  printf("%g %g %g %g %g %g\n", dinf, dninf, huge, dnan, dnnan, zz);
  printf("%Lg %Lg %Lg\n", linf, lnan, lnnan);
  printf("%g %g %g %g\n", cnan, quot, nquot, l);
  printf("%d %d %d %d\n", isnan(bigsum) != 0, isnan(zz) != 0, signbit(nbigsum) != 0, isinf(big) != 0);
  return 0;
}
