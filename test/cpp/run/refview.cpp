// std::ranges::ref_view held by a class and its size(): a trailing requires-clause takes the class's arguments (0.110)
#include <cstdio>
#include <ranges>
#include <vector>
template <class V> struct H { V b; H(V x) : b(std::move(x)) {} };
int main() {
  std::vector<int> v{1, 2, 3};
  std::ranges::ref_view<std::vector<int>> r(v);
  H<std::ranges::ref_view<std::vector<int>>> h(r);
  std::printf("%d\n", (int) h.b.size());
  return 0;
}
