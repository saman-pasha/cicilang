// <compare>'s customization point objects (0.219): of ints, of doubles (strong_order's total order: -0.0 before 0.0, a NaN
// after every number), of a class with a defaulted <=>, and the fallbacks over ints and that class. libc++ 18's
// `__strong_order::__fn' named the object `strong_order' unqualified, with no poison pill, and the call asked itself
#include <cmath>
#include <compare>
#include <cstdio>
struct P { int a; auto operator<=>(const P &) const = default; };
int main() {
  std::printf("%d %d %d\n", (int)(std::strong_order(1, 2) < 0), (int)(std::weak_order(2, 2) == 0), (int)(std::partial_order(3, 1) > 0));
  std::printf("%d %d %d\n", (int)(std::strong_order(-0.0, 0.0) < 0), (int)(std::strong_order(1.0, std::nan("")) < 0), (int)(std::partial_order(std::nan(""), 1.0) == std::partial_ordering::unordered));
  std::printf("%d %d %d\n", (int)(std::strong_order(P{1}, P{2}) < 0), (int)(std::weak_order(P{3}, P{3}) == 0), (int)(std::partial_order(P{4}, P{3}) > 0));
  std::printf("%d %d %d\n", (int)(std::compare_weak_order_fallback(5, 5) == 0), (int)(std::compare_strong_order_fallback(P{1}, P{2}) < 0), (int)(std::compare_partial_order_fallback(P{3}, P{1}) > 0));
  return 0;
}
