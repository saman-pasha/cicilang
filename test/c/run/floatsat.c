/* floating constants converted to integer types that do not hold them (1.6.23): the conversion is undefined (C17
   6.3.1.4/1), and clang's fold saturates, as gcc's does -- the type's maximum or its minimum --, where the fold wrapped
   (0.108): `int a = 1e10;' was 1410065408. A value in range is truncated toward zero, a bool is 0 or 1 */
#include <stdio.h>
int a = 1e10;
int b = -1e10;
unsigned char c = 300.0;
unsigned u = -5.0;
short s = 40000.5;
long long ll = 1e19;
unsigned long long ull = 2e19;
_Bool bo = 0.5;
signed char sc = -200.7;
int in = 7.9, im = -7.9;
static const long sl = (long)-9.3e18;
int main(void) {
  printf("%d %d %u %u %d %lld %llu %d %d\n", a, b, c, u, s, ll, ull, bo, sc);
  printf("%d %d %ld\n", in, im, sl);
  return 0;
}
