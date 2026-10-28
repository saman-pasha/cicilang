// functions and objects of one name across the headers' reads (0.221): a call qualified by std takes std's function template
// where another header's read holds an object of the name in std::ranges or std::ranges::views -- std::reverse and
// std::transform beside <ranges>' views::reverse and views::transform, std::for_each, std::mismatch and std::upper_bound
// beside the ranges objects that <vector> and <sstream> hold at C++20 -- and each object keeps its own qualified call
#include <algorithm>
#include <cstdio>
#include <ranges>
#include <sstream>
#include <vector>
struct Sum { int s = 0; void operator()(int x) { s += x; } };
int main() {
  std::vector<int> v{1, 2, 3}, w(3), u{1, 5, 3};
  int n = 0;
  for (int x : std::views::reverse(v)) n = n * 10 + x;
  std::reverse(v.begin(), v.end());
  std::transform(v.begin(), v.end(), w.begin(), [](int x) { return x * 10; });
  std::printf("%d %d %d %d %d\n", n, v[0], v[2], w[0], w[2]);
  std::ranges::for_each(v, [](int) {});
  Sum f = std::for_each(v.begin(), v.end(), Sum{});
  auto m = std::mismatch(v.begin(), v.end(), u.begin());
  auto ub = std::upper_bound(u.begin(), u.end(), 2, [](int a, int b) { return a < b; });
  std::printf("%d %d %d %d\n", f.s, *m.first, *m.second, (int)(ub - u.begin()));
  std::ranges::transform(v, w.begin(), [](int x) { return x + 1; });
  std::printf("%d %d %d\n", w[0], (int)std::ranges::size(v), (int)std::size(v));
  return 0;
}
