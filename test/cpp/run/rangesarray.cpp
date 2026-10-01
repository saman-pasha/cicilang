// ranges::upper_bound over a constant C array, as libc++'s grapheme-cluster table is searched by std::format's
// width estimate: ranges::begin's `_Tp (&)[_Np]' keeps the element's const, and its requires-clause is checked bound.
#include <algorithm>
#include <cstdio>
#include <cstdint>
static constexpr uint32_t e[5] = {1, 3, 5, 7, 9};
int main() {
  std::ptrdiff_t i = std::ranges::upper_bound(e, 4u) - e;
  std::ptrdiff_t j = std::ranges::upper_bound(e, e + 5, 7u) - e;
  std::printf("%d %d\n", (int) i, (int) j);
  return 0;
}
