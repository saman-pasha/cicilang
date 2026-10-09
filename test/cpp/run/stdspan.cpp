// std::span (C++20, 0.117): `span<_Tp, dynamic_extent>' is a PARTIAL SPECIALIZATION on a name -- `inline constexpr size_t
// dynamic_extent = numeric_limits<size_t>::max()' -- whose value is 2^64 - 1, past what cocolog's integers hold; the pattern
// matched nothing, so the primary was instantiated with that extent and its members' `_Extent * sizeof(element_type)' ran away
// (3 GB). A span over an array, a vector and a std::array, subspans, element access, a fixed extent
#include <array>
#include <cstdio>
#include <span>
#include <vector>
int sum(std::span<const int> s) { int t = 0; for (int x : s) t += x; return t; }
int main() {
  int arr[5] = {1, 2, 3, 4, 5};
  std::span<int> sp(arr);
  std::printf("%zu %zu %d %d\n", sp.size(), sp.size_bytes(), sp.front(), sp.back());
  auto sub = sp.subspan(1, 3);
  std::printf("%zu %d %d\n", sub.size(), sub[0], sub[2]);
  std::printf("%d %d %d\n", sum(sp), sum(sp.first(2)), sum(sp.last(2)));
  std::vector<int> v = {10, 20, 30};
  std::span<int> sv(v);
  sv[1] = 21;
  std::printf("%d %d\n", v[1], sum(sv));
  std::span<int, 3> fixed(arr, 3);
  std::printf("%zu %d\n", fixed.size(), fixed[2]);
  std::array<int, 4> a4 = {7, 8, 9, 10};
  std::printf("%d %d\n", sum(a4), (int)sp.empty());
  return 0;
}
