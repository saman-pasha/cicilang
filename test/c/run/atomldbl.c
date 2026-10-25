/* an _Atomic long double's ++, --, += and *=, each one read-modify-write: x86's through libatomic's compare-exchange (C17 6.5.16.2/3) */
#include <stdio.h>
#include <stdatomic.h>
_Atomic long double x = 1.5L;
int main(void) {
  _Atomic long double y = 10.0L;
  x++; x += 2.25L; ++x; x -= 0.5L; x *= 2.0L; x /= 4.0L;
  long double old = x--;
  y /= 8.0L; y *= 3.0L; --y;
  long double z = atomic_load(&y);
  long double w = atomic_exchange(&y, 7.0L);
  printf("%.4Lf %.4Lf %.4Lf %.4Lf %.4Lf\n", (long double) x, old, z, w, (long double) y);
  return 0;
}
