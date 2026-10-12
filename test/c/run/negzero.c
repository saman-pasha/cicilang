/* A negative zero in a floating constant keeps its sign, as clang folds it: a global, a static, an array's item, a
   struct's member, a float, a long double, a complex's real part, `0.0 * -1.0', and a constant divided by -0.0. */
#include <stdio.h>

double g = -0.0;
float gf = -0.0f;
long double gl = -0.0L;
double prod = 0.0 * -1.0;
double quot = 1.0 / -0.0;
double nquot = -1.0 / -0.0;
static double s = -0.0;
double arr[3] = { -0.0, 0.0, -0.0 * 2.0 };
struct pt { double x, y; } p = { -0.0, 1.0 };
float fa[2] = { -0.0f, (float) -0.0 };
_Complex double z = -0.0;

int main(void) {
  static double ls = -0.0;
  static long double lls = -0.0L;
  double r = -0.0;
  printf("%g %g %Lg %g %g %g\n", g, (double) gf, gl, prod, s, ls);
  printf("%g %g %g %g %g %Lg\n", quot, nquot, arr[0], arr[2], p.x, lls);
  printf("%g %g %g %g\n", (double) fa[0], (double) fa[1], __real__ z, __imag__ z);
  printf("%g %g %g\n", 1.0 / r, 1.0 / arr[1], 1.0 / g);
  return 0;
}
