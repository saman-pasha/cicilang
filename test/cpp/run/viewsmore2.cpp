// Views that did not build until 0.132, the second set, at C++23: join (its iterator takes the inner range through
// a `decltype(auto)' lambda), split and lazy_split (their deduction guides, their iterators' friends and bindings),
// and ranges::to with a container's template and with a class.
#include <cstdio>
#include <ranges>
#include <string>
#include <vector>
namespace views = std::views;
int main() {
  std::vector<std::vector<int>> vv{{1, 2}, {3}, {}, {4, 5}};
  for (int x : views::join(vv)) std::printf("join %d\n", x);
  std::string s = "ab cd  ef";
  for (auto &&w : views::split(s, ' ')) {
    std::printf("split [");
    for (char c : w) std::printf("%c", c);
    std::printf("]\n");
  }
  for (auto &&w : views::lazy_split(s, ' ')) {
    std::printf("lazy_split [");
    for (char c : w) std::printf("%c", c);
    std::printf("]\n");
  }
  auto v = std::ranges::to<std::vector>(vv[3]);
  auto t = std::ranges::to<std::vector<int>>(vv[0]);
  std::printf("to %d %d %d %d\n", (int) v.size(), v[1], (int) t.size(), t[0]);
  return 0;
}
