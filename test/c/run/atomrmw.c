/* every compound assignment and increment of an _Atomic object is one read-modify-write (C17 6.5.16.2/3, 6.5.2.4/2) */
#include <stdio.h>
_Atomic int x = 7;
_Atomic unsigned u = 100;
_Atomic float f = 1.5f;
_Atomic double d = 2.5;
_Atomic char c = 3;
int arr[8];
_Atomic(int *) p = arr;
int main(void) {
  x *= 3; x /= 2; x %= 7; x <<= 2; x >>= 1;
  u *= 3; u /= 7; u <<= 3;
  f *= 4.0f; f /= 2.0f; d *= 3.0; d /= 0.5;
  c *= 5; c -= 1;
  p++; p++; --p;
  long q = p++ - arr;
  printf("%d %u %.2f %.2f %d %td %ld\n", (int) x, (unsigned) u, (double) f, (double) d, (int) c, (int *) p - arr, q);
  return 0;
}
