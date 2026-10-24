#include <array>
#include <cstdio>
#include <type_traits>
#include <utility>
// a static member function called with no argument in a template argument, `rank()', where <type_traits> has a class
// template `rank': the call, not a function type ([temp.arg]/2)
template <int N> struct Ext {
  static constexpr int rank() { return N; }
  static constexpr int twice() { return 2 * N; }
};
template <class E> struct Span {
  static constexpr int rank() { return E::rank(); }
  template <std::size_t... Is> static int sum(std::index_sequence<Is...>) { return (0 + ... + (int) Is); }
  static int all() { return sum(std::make_index_sequence<rank()>()); }
  std::array<int, rank()> idx{};
  std::array<int, E::twice()> more{};
};
int main() {
  Span<Ext<4>> s;
  std::printf("%d %d %d %d\n", s.all(), (int) s.idx.size(), (int) s.more.size(), (int) std::rank<int[2][3]>::value);
  return 0;
}
