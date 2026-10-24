#include <algorithm>
#include <cstdio>
#include <execution>
#include <numeric>
#include <vector>
// C++17 and C++20 execution policies over the parallel algorithms (libc++'s PSTL, its experimental part)
int main() {
  std::vector<int> v = {5, 3, 9, 1, 7};
  std::sort(std::execution::seq, v.begin(), v.end());
  for (int x : v) std::printf("%d ", x);
  std::printf("\n");
  std::for_each(std::execution::par, v.begin(), v.end(), [](int &x) { x *= 2; });
  long s = std::reduce(std::execution::par_unseq, v.begin(), v.end(), 0L);
  std::vector<int> w(v.size());
  std::transform(std::execution::unseq, v.begin(), v.end(), w.begin(), [](int x) { return x + 1; });
  long c = std::count_if(std::execution::par, w.begin(), w.end(), [](int x) { return x > 10; });
  int t = std::transform_reduce(std::execution::par, v.begin(), v.end(), w.begin(), 0);
  auto it = std::find(std::execution::par, w.begin(), w.end(), 15);
  std::fill(std::execution::par, v.begin(), v.begin() + 2, 0);
  std::printf("%ld %ld %d %ld %d %d\n", s, c, t, (long) (it - w.begin()), v[0], v[2]);
  bool any = std::any_of(std::execution::par, w.begin(), w.end(), [](int x) { return x == 19; });
  std::vector<int> o(5);
  std::copy(std::execution::par, w.begin(), w.end(), o.begin());
  std::printf("%d %d %d\n", (int) any, o[4], (int) std::equal(std::execution::par, w.begin(), w.end(), o.begin()));
  return 0;
}
