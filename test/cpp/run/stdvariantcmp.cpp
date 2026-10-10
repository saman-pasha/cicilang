// std::variant at C++20 (0.121): the three-way comparison of variants -- `a <=> b' is the alternatives' own when the indices agree and the indices' otherwise -- which needs
// `three_way_comparable<std::string>' and `<=>' of two variants of different alternative types (the string comparison of `stringcmp20.cpp').
#include <compare>
#include <cstdio>
#include <string>
#include <variant>
int main() {
  std::variant<int, std::string> a = 3, b = std::string("x"), c = 5, d = std::string("y");
  std::printf("%d %d %d %d\n", (int) ((a <=> c) < 0), (int) ((a <=> b) < 0), (int) ((b <=> d) < 0), (int) (a == a));
  std::printf("%d %d %d\n", (int) (a < c), (int) (c > a), (int) (b <= d));
  auto r = (a <=> c);
  std::printf("%d\n", (int) (r == std::strong_ordering::less));
  std::variant<int, double> x = 1, y = 2.5;
  auto q = (x <=> y);
  std::printf("%d\n", (int) (q == std::strong_ordering::less));
  return 0;
}
