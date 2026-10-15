// A constructor template delegating to an abbreviated constructor (`std::convertible_to<I> auto x') with calls of
// customization points as the arguments, `std::ranges::begin(r)' (subrange's constructor from a range).
#include <concepts>
#include <cstdio>
#include <ranges>
#include <vector>
template <class I>
struct R {
  I b, e;
  constexpr R(std::convertible_to<I> auto x, I y) : b(x), e(y) {}
  template <class Rng>
  constexpr R(Rng &&r) : R(std::ranges::begin(r), std::ranges::end(r)) {}
};
int main() {
  std::vector<int> v{4, 5, 6};
  R<std::vector<int>::iterator> r(v);
  int s = 0;
  for (auto it = r.b; it != r.e; ++it) s += *it;
  std::printf("%d %d\n", s, (int) (r.e - r.b));
  return 0;
}
