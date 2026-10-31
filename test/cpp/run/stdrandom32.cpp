// <random> over 32-bit engines, as macOS defines mt19937 and minstd_rand (uint_fast32_t is 32 bits there, 64 on glibc): a
// library class's static of 32 bits holds its type's value (0.250) -- __independent_bits_engine's _Rp, max() - min() + 1, is
// 0, and its draw takes no loop; folded as 2^32 it waited for a value below 0, and stdrandom.cpp never ended on the Intel Mac
#include <cstdint>
#include <cstdio>
#include <random>
#include <vector>
#include <algorithm>
using mt32 = std::mersenne_twister_engine<std::uint32_t, 32, 624, 397, 31, 0x9908b0df, 11, 0xffffffff, 7, 0x9d2c5680, 15,
                                          0xefc60000, 18, 1812433253>;
using minstd32 = std::linear_congruential_engine<std::uint32_t, 48271, 0, 2147483647>;
int main() {
  mt32 g(42);
  std::uniform_int_distribution<int> d(1, 6);
  int a = d(g), b = d(g), c = d(g);
  std::printf("%u %d %d %d\n", (unsigned) g(), a, b, c);
  std::uniform_real_distribution<double> u(0.0, 1.0);
  double x = u(g), y = u(g);
  std::printf("%.6f %.6f\n", x, y);
  std::bernoulli_distribution coin(0.25);
  int heads = 0;
  for (int i = 0; i < 1000; ++i) heads += coin(g) ? 1 : 0;
  std::printf("%d\n", heads);
  minstd32 m(3);
  std::uniform_int_distribution<unsigned> w(0, 4000000000u);
  std::printf("%u %u %u\n", (unsigned) m(), w(m), w(m));
  std::independent_bits_engine<mt32, 3, std::uint32_t> ibe(1);
  unsigned p = ibe(), q = ibe(), r = ibe();
  std::printf("%u %u %u\n", p, q, r);
  std::vector<int> v{1, 2, 3, 4, 5, 6, 7, 8};
  std::shuffle(v.begin(), v.end(), g);
  for (int e : v) std::printf("%d ", e);
  std::printf("\n");
  return 0;
}
