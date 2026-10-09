// <numeric> (0.117): iota, accumulate (with and without an operation), partial_sum, adjacent_difference, inner_product, gcd, lcm and the
// sequential reduce -- untried until the library sweep, and all of them run
#include <numeric>
#include <vector>
#include <cstdio>
int main() {
  std::vector<int> v(6);
  std::iota(v.begin(), v.end(), 1);
  std::printf("%d %d\n", std::accumulate(v.begin(), v.end(), 0), std::accumulate(v.begin(), v.end(), 1, [](int a, int b) { return a * b; }));
  std::vector<int> p(6); std::partial_sum(v.begin(), v.end(), p.begin());
  std::vector<int> d(6); std::adjacent_difference(p.begin(), p.end(), d.begin());
  std::printf("%d %d %d\n", p[5], d[3], std::inner_product(v.begin(), v.end(), v.begin(), 0));
  std::printf("%d %d %d\n", std::gcd(12, 18), std::lcm(4, 6), std::reduce(v.begin(), v.end(), 0));
  return 0;
}
