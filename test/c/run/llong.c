/* `3ll' is a long long and `3ull' an unsigned long long (C 6.4.4.1/5; 0.179): _Generic, globals, an array bound, a null pointer
   constant, a case label, an enumerator and GNU's imaginary forms `3lli', `4ulli' -- they were a long and an unsigned long */
#include <stdio.h>
#define T(x) _Generic((x), long: "long", long long: "long long", unsigned long: "unsigned long", unsigned long long: "unsigned long long", int: "int", unsigned: "unsigned", default: "other")
long long g = 5LL; unsigned long long h = 18446744073709551615ULL; long long m = -9223372036854775807LL - 1;
unsigned long long sh = 1ull << 63; long long arr[2ll] = { 7ll, 0x10LL };
int *np = 0ll;
int main(void) {
  printf("%s %s %s %s %s %s %s\n", T(3ll), T(3ull), T(3l), T(3ul), T(0x10LL), T(017uLL), T(3llu));
  printf("%lld %llu %lld %zu %zu %llu\n", g, h, m, sizeof(3ll), sizeof 3ull, sh);
  long long a[3ll] = {1ll, 2ll, 3ll};
  printf("%lld %d %lld %lld\n", a[2] + (1ll << 40), (int)(3ll == 3), arr[0], arr[1]);
  _Complex long long c = 3lli; _Complex unsigned long long d = 4ulli;
  printf("%lld %s %s %d\n", (long long) __imag__ c, T(__imag__ c), T(__imag__ d), np == 0);
  switch (5ll) { case 5ll: printf("case\n"); break; default: break; }
  enum { E = 9223372036854775807LL > 0 }; printf("%d %d\n", E, (int) sizeof(char [4ll]));
  return 0;
}
