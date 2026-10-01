// C++'s char32_t promotes to its underlying unsigned int ([conv.prom]/8), and an arithmetic result has no qualifiers:
// common_reference of `const char32_t &' and `const unsigned &' is unsigned, and ranges::less compares the two, as
// libc++'s grapheme-cluster search in std::format's width estimate does.
#include <cstdio>
#include <functional>
#include <concepts>
#include <type_traits>
int main() {
  char32_t c = U'a';
  unsigned u = 98;
  std::printf("%d %d %d %d %d\n", (int) std::is_same_v<std::common_reference_t<const char32_t &, const unsigned &>, unsigned>,
              (int) std::common_reference_with<const char32_t &, const unsigned &>, (int) std::equality_comparable_with<char32_t, unsigned>,
              (int) std::totally_ordered_with<char32_t, unsigned>, (int) std::ranges::less{}(c, u));
  return 0;
}
