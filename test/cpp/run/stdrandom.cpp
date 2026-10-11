// <random>: seeded engines (mt19937, mt19937_64, minstd_rand) through the uniform and Bernoulli distributions and
// std::shuffle -- a build that never finished before 0.136 (a class's static constants folded again at every use).
#include <algorithm>
#include <cstdio>
#include <random>
#include <vector>
int main() {
  std::mt19937 g(42);
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
  std::mt19937_64 g64(7);
  std::uniform_int_distribution<long long> big(0, 1000000000000LL);
  std::printf("%llu %lld\n", (unsigned long long) g64(), big(g64));
  std::minstd_rand m(3);
  std::printf("%u %u\n", (unsigned) m(), (unsigned) m());
  std::vector<int> v{1, 2, 3, 4, 5, 6, 7, 8};
  std::shuffle(v.begin(), v.end(), g);
  for (int e : v) std::printf("%d ", e);
  std::printf("\n");
  return 0;
}
