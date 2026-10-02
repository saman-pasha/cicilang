// A reference parameter takes an array as it is ([temp.deduct.call]/2): `T &' over a `const uint32_t[3]' deduces the
// array, so is_array_v holds -- ranges::begin is written so -- and common_reference of two lvalues of one type under two
// spellings (`const unsigned &', `uint32_t &') is that reference, which indirectly_readable asks of `const uint32_t *'.
#include <cstdio>
#include <cstdint>
#include <type_traits>
#include <iterator>
struct B { template <class T> requires std::is_array_v<std::remove_cv_t<T>> auto operator()(T &t) const { return t + 0; } };
inline constexpr B beg{};
static constexpr uint32_t e[3] = {1, 2, 3};
template <class T> int size_of(T &) { return (int) sizeof(T); }
int main() {
  std::printf("%d %d %d %d %d %d\n", (int) std::is_same_v<decltype(beg(e)), const uint32_t *>, (int) *beg(e),
              (int) std::is_same_v<std::common_reference_t<const unsigned &, uint32_t &>, const unsigned &>,
              (int) std::indirectly_readable<const uint32_t *>, (int) std::input_iterator<const uint32_t *>, size_of(e));
  return 0;
}
