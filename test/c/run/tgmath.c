/* <tgmath.h>'s type-generic functions (C17 7.25; 0.194), the compiler's own header: the function each argument's type chooses -- a real,
   a complex, the type the arguments' sum has -- and the result's type; glibc's refused clang's macros silently */
#include <stdio.h>
#include <tgmath.h>
#include <complex.h>
#define KIND(x) _Generic((x), float: "float", double: "double", long double: "long double", \
  float complex: "float complex", double complex: "double complex", long double complex: "long double complex", default: "other")
int main(void) {
  double complex z = -4.0;
  float complex zf = -9.0f;
  long double ld = 2.0L;
  float f = 16.0f;
  int i = 25;
  double complex r = sqrt(z);
  float complex rf = sqrt(zf);
  printf("%g %g %g %g\n", creal(r), cimag(r), crealf(rf), cimagf(rf));
  printf("%s %s %s %s %s\n", KIND(sqrt(z)), KIND(sqrt(zf)), KIND(sqrt(ld)), KIND(sqrt(f)), KIND(sqrt(i)));
  printf("%g %g %Lg %g\n", sqrt(f), sqrt(i), sqrt(ld), exp(1.0));
  printf("%s %s %s\n", KIND(pow(f, 2)), KIND(pow(f, 2.0f)), KIND(atan2(ld, 1)));
  printf("%g %g %g\n", pow(2.0f, 10.0f), atan2(1.0, 1.0) * 4, fabs(-3.5f));
  double complex w = 3.0 + 4.0 * I;
  printf("%s %g %s\n", KIND(fabs(w)), fabs(w), KIND(exp(w)));
  printf("%g %g\n", creal(conj(w)), cimag(conj(w)));
  printf("%d %d %d\n", __builtin_classify_type(z), __builtin_classify_type(f), __builtin_classify_type(i));
  return 0;
}
