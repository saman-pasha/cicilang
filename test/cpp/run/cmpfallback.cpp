// <compare>'s fallbacks over a class with == and < and no <=> (0.221): `compare_three_way()(t, u)' is taken out of
// std::strong_order's candidates, and each fallback takes its own road
#include <compare>
#include <cstdio>
struct Q { int v; bool operator==(const Q &) const = default; bool operator<(const Q &o) const { return v < o.v; } };
int main() {
  std::printf("%d %d %d\n", (int)(std::compare_strong_order_fallback(Q{1}, Q{2}) < 0), (int)(std::compare_weak_order_fallback(Q{2}, Q{2}) == 0),
              (int)(std::compare_partial_order_fallback(Q{3}, Q{1}) > 0));
  return 0;
}
