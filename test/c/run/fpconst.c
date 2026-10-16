/* A floating global's constant, spelled for its type: a subnormal double on the 2^-1074 grid, and a cast to float or
   _Float16 inside the initializer rounded to that type before the value goes on; a tie to the even value (0.154: away
   from zero, 16777217.0 was 16777218 in a float). */
#include <stdio.h>
double a = 1e-310;
double b = -4.9406564584124654e-324;
float c = 1e-40f;
double d = 2.2250738585072009e-308;
double e = (float) 0.1;
double f = (float) 1e-40;
double g = (_Float16) 0.1;
double h = (float) 3.4e38 * 2;
float i = (float) 0.1 + (float) 0.2;
double j = (double) (float) (1.0 / 3) * 3;
float k = 16777217.0, k2 = 1.00000005960464477539, k3 = 16777219.0;
_Float16 m = 2049.0, m2 = 2051.0;
int main(void) {
  printf("%a %a %a %a\n", a, b, (double) c, d);
  printf("%a %a %a %a %a %a\n", e, f, g, h, (double) i, j);
  printf("%a %a %a %a %a\n", (double) k, (double) k2, (double) k3, (double) m, (double) m2);
  return 0;
}
