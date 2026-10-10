/* the decimal floating types across the SysV ABI (0.129): built by gcc and by cicilang, called both ways (test/driver.sh) */
#include <stdio.h>
struct q { _Decimal128 v; };
struct p { _Decimal64 a; _Decimal32 b; };
struct q twice(struct q x);
struct p swap(struct p x);
_Decimal64 sum(int n, ...);
_Decimal32 mix(_Decimal32 a, _Decimal64 b, _Decimal128 c, int k);
_Decimal128 cube(_Decimal128 x);
int main(void) {
  struct q a = { 1.25dl };
  struct q b = twice(a);
  struct p c = swap((struct p){ 3.5dd, 0.5df });
  printf("%g %g %g\n", (double)b.v, (double)c.a, (double)c.b);
  printf("%g %g %g\n", (double)sum(3, 0.1dd, 0.2dd, 0.3dd), (double)mix(0.5df, 0.25dd, 0.125dl, 2), (double)cube(1.5dl));
  return 0;
}
