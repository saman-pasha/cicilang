// A static member array of a class template initialized by a pack expansion of a constexpr call: one item per
// element, each folded to its constant. libc++ 18's basic_format_string holds
// `static constexpr array<__arg_t, sizeof...(_Args)> __types_{__determine_arg_t<_Context, ...>()...}'.
#include <cstdio>
enum class K : unsigned char { a, b, c };
template <class T> constexpr K kind() { return sizeof(T) == 4 ? K::b : K::c; }
template <class T, unsigned N> struct Arr { T e_[N]; constexpr T at(unsigned i) const { return e_[i]; } };
template <class... As> struct S {
  static constexpr Arr<K, sizeof...(As)> types_{kind<As>()...};
};
int main() {
  std::printf("%d %d\n", (int) S<int, double>::types_.at(0), (int) S<int, double>::types_.at(1));
  return 0;
}
