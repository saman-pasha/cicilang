// C++20 COMPARISONS THROUGH A FREE `operator<=>' (0.121): libc++ 18 writes a string's comparison as `operator<=>' alone, so `a < b' of two strings -- and every
// `std::map<std::string, ...>' -- is the rewritten candidate `(a <=> b) < 0' over a FREE function, its operands swapped and the comparison mirrored where only the
// right one's class takes them (`"b" < s'; a string against a string_view). `convertible_to' of a class to another by the first's conversion function
// (`strong_ordering' to `partial_ordering') makes `three_way_comparable' and `totally_ordered' of a string hold.
#include <compare>
#include <concepts>
#include <cstdio>
#include <map>
#include <string>
#include <string_view>
#include <vector>
template <class T> concept has_lt = requires(const T &a, const T &b) { { a < b } -> std::convertible_to<bool>; };
template <class T> concept has_cmp = requires(const T &a, const T &b) { { a <=> b } -> std::convertible_to<std::partial_ordering>; };
int main() {
  std::map<std::string, int> m;
  m["b"] = 2; m["a"] = 1; m["c"] = 3;
  for (auto &kv : m) std::printf("%s=%d\n", kv.first.c_str(), kv.second);
  std::string x("a"), y("b");
  std::printf("%d %d %d %d\n", (int) (x < y), (int) (x > y), (int) (x <= y), (int) (x >= y));
  std::printf("%d %d %d %d\n", (int) (x < "b"), (int) (x > "b"), (int) (x <= "a"), (int) (x >= "b"));
  std::printf("%d %d %d %d\n", (int) ("b" < x), (int) ("b" > x), (int) ("a" <= x), (int) ("b" >= x));
  std::string_view v("m"), w("n");
  std::printf("%d %d %d %d\n", (int) (v < w), (int) (v > w), (int) (v <= "m"), (int) ("n" >= v));
  std::printf("%d %d\n", (int) (x < w), (int) (v >= y));
  std::printf("%d %d\n", (int) std::convertible_to<std::strong_ordering, std::partial_ordering>, (int) std::convertible_to<std::partial_ordering, std::strong_ordering>);
  std::printf("%d %d %d\n", (int) has_lt<std::string>, (int) has_cmp<std::string>, (int) has_cmp<std::string_view>);
  std::printf("%d %d %d\n", (int) std::three_way_comparable<std::string>, (int) std::totally_ordered<std::string>, (int) std::three_way_comparable<std::vector<int>>);
  std::printf("%d %d\n", (int) std::three_way_comparable<int>, (int) std::three_way_comparable<std::strong_ordering>);
  return 0;
}
