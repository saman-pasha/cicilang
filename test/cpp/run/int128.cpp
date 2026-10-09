// __int128 in C++: a template over it, the typedef names clang predefines, the arithmetic and the conversions.
// libc++ keeps its no-int128 configuration (the library's own choice, by design); a program's __int128 runs.
#include <cstdio>
typedef unsigned __int128 u128;
template <class T> struct Box { T v; T twice() const { return v + v; } };
static void show(u128 v) { char b[48]; int n = 0; if (!v) b[n++] = '0'; while (v) { b[n++] = (char)('0' + (int)(v % 10)); v /= 10; } while (n) std::putchar(b[--n]); std::putchar('\n'); }
__int128 mulw(__int128 a, __int128 b) { return a * b; }
static_assert(sizeof(u128) == 16 && alignof(__int128) == 16, "layout");
int main() {
  Box<u128> b{(u128)1 << 80};
  show(b.twice());
  u128 f = 1; for (int i = 2; i <= 30; i++) f *= i; show(f);
  __int128_t m = -(__int128_t)5; __uint128_t q = (__uint128_t)m;
  std::printf("%d %d %d\n", (int)sizeof(u128), (int)(m < 0), (int)(q >> 120));
  std::printf("%lld\n", (long long)(mulw(123456789012345LL, 1000003LL) / 7));
  Box<__int128> c{-7};
  std::printf("%d %d\n", (int)c.twice(), (int)(c.twice() < 0));
  return 0;
}
