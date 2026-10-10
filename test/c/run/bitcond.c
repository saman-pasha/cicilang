/* THE BIT BUILTINS ANSWER AN INT (0.129): the inference had no type for `__builtin_clzll(x)', so a conditional over two such
   calls had none and the lowering refused it, `type(unknown)' -- libc++'s `__libcpp_clz(__uint128_t)' is written so. */
#include <stdio.h>

static int clz128(unsigned __int128 x) {
  return ((x >> 64) == 0) ? (64 + __builtin_clzll((unsigned long long)x)) : __builtin_clzll((unsigned long long)(x >> 64));
}

static int bits(unsigned long long v, int which) {
  return which == 0 ? __builtin_popcountll(v) : which == 1 ? __builtin_ctzll(v) : __builtin_clzll(v);
}

int main(void) {
  unsigned x = 0xF0u;
  printf("%d %d\n", clz128(1), clz128((unsigned __int128)1 << 100));
  printf("%d %d %d\n", bits(0xFF00ull, 0), bits(0xFF00ull, 1), bits(0xFF00ull, 2));
  printf("%d %d\n", x ? __builtin_ctz(x) : -1, x > 1 ? __builtin_popcount(x) : __builtin_clz(x));
  printf("%d %d\n", _Generic(__builtin_popcountl(3ul), int: 1, default: 0), (int)sizeof(__builtin_clzl(5ul)));
  return 0;
}
