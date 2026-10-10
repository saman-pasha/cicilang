// <bit> over an unsigned __int128: libc++ 21 counts it with __builtin_clzg and kin, libc++ 18 in two 64-bit halves.
#include <bit>
#include <cstdio>
int main() {
  unsigned __int128 x = 1;
  x <<= 100;
  unsigned __int128 y = ~(unsigned __int128) 0 >> 3;
  std::printf("%d %d %d\n", std::countl_zero(x), std::countr_zero(x), std::popcount(x));
  std::printf("%d %d %d %d\n", std::countl_zero(y), std::countl_one(y), std::countr_one(y), std::bit_width(y));
  std::printf("%d\n", std::has_single_bit(x));
  return 0;
}
