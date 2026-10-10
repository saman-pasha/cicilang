// Views that did not build until 0.132, each over a vector or a string and walked by a range-for, at C++23:
// empty, single, counted, chunk_by, common over iota, zip (its size too), elements, drop_while, as_rvalue, repeat.
#include <ranges>
#include <vector>
#include <string>
#include <utility>
#include <cstdio>
namespace views = std::views;
int main() {
  std::vector<int> a{1, 2, 3, 4, 5};
  std::vector<int> b{10, 20, 30};
  std::vector<std::pair<int, int>> pv{{1, 2}, {3, 4}};
  int n = 0;
  for (auto&& x : views::empty<int>) n += x;
  std::printf("empty %d\n", n);
  for (auto&& x : views::single(7)) std::printf("single %d\n", x);
  for (auto&& x : views::counted(a.begin(), 3)) std::printf("counted %d\n", x);
  for (auto&& g : views::chunk_by(a, [](int x, int y) { return y == x + 1 && y != 3; })) {
    std::printf("chunk");
    for (int x : g) std::printf(" %d", x);
    std::printf("\n");
  }
  for (auto&& x : views::common(views::iota(1, 4))) std::printf("common %d\n", x);
  auto z = views::zip(a, b);
  std::printf("zip size %d\n", (int) z.size());
  for (auto&& [x, y] : z) std::printf("zip %d %d\n", x, y);
  for (auto&& x : views::elements<1>(pv)) std::printf("elements %d\n", x);
  for (auto&& x : views::drop_while(a, [](int x) { return x < 4; })) std::printf("drop_while %d\n", x);
  std::vector<std::string> vs{"x", "yy"};
  for (auto&& s : views::as_rvalue(vs)) std::printf("as_rvalue %s\n", s.c_str());
  for (auto&& x : views::repeat(9, 2)) std::printf("repeat %d\n", x);
  return 0;
}
