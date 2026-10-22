// C++20: a scalar <=> is <compare>'s category -- strong_ordering for integers and pointers, partial_ordering where an
// operand is floating -- to `auto', to decltype, to a template's deduction and to an overload, never the operands'
// type (0.186).
#include <compare>
#include <cstdio>
#include <type_traits>

template <class T> int kind(T) {
  if constexpr (std::is_same_v<T, std::strong_ordering>) return 1;
  else if constexpr (std::is_same_v<T, std::partial_ordering>) return 2;
  else return 0;
}
int pick(std::partial_ordering) { return 20; }
int pick(double) { return 30; }

int main() {
  auto a = 1 <=> 2;
  auto b = 2.5 <=> 1.5;
  int x = 3, y = 4;
  auto c = &x <=> &y;
  decltype(1 <=> 2) d = std::strong_ordering::equal;
  auto e = 1u <=> 2u;
  auto f = 0.5 <=> 1;
  std::printf("%d %d %d %d %d %d\n", kind(a), kind(b), kind(c), kind(d), kind(e), kind(f));
  std::printf("%d %d %d %d %d\n", (int) (a < 0), (int) (b > 0), (int) (d == 0), (int) (e == std::strong_ordering::less),
              (int) (f == std::partial_ordering::less));
  std::printf("%d %d %d\n", (int) std::is_same_v<decltype(b), std::partial_ordering>,
              (int) std::is_same_v<decltype(x <=> y), std::strong_ordering>, pick(2.0 <=> 3.0));
  return 0;
}
