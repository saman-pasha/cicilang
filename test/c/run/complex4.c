/* _Complex long double (0.112): C11's CMPLXL from the compiler's own <complex.h>, the imaginary literal 1.0li of
   long double, arithmetic in x87 components and the C library's creall and cimagl over them */
#include <complex.h>
#include <stdio.h>
#ifndef CMPLXL
#define CMPLXL(x, y) __builtin_complex((long double) (x), (long double) (y))
#endif
int main(void) {
  long double complex z = CMPLXL(1.5L, 2.25L);
  long double complex w = z * 2;
  long double complex v = 1.0li + 0.5L;
  printf("%Lf %Lf\n", creall(w), cimagl(w));
  printf("%Lf %Lf %d %d\n", creall(v), cimagl(v), (int) sizeof(z), (int) sizeof(1.0li));
  return 0;
}
