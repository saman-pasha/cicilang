// `if constexpr' over a constexpr call is decided through the evaluator, and the discarded branch is not walked:
// libc++ 18's __format_arg_store writes `if constexpr (__format::__use_packed_format_arg_store(sizeof...(_Args)))',
// and its other branch names a member the packed store does not have.
#include <cstdio>
#include <type_traits>
constexpr bool small(unsigned n) { return n <= 2; }
template <unsigned N> struct Packed { int values[N]; };
template <unsigned N> struct Unpacked { long args[N]; };
template <class... As> struct Store {
  using St = std::conditional_t<small(sizeof...(As)), Packed<sizeof...(As)>, Unpacked<sizeof...(As)>>;
  St s{};
  int fill() {
    if constexpr (small(sizeof...(As))) {
      for (unsigned i = 0; i < sizeof...(As); i++) s.values[i] = (int) i + 1;
      return s.values[0] + s.values[sizeof...(As) - 1];
    } else {
      for (unsigned i = 0; i < sizeof...(As); i++) s.args[i] = 10;
      return (int) s.args[0] * (int) sizeof...(As);
    }
  }
};
int main() {
  Store<int, int> a;
  Store<int, int, int, int, int> b;
  std::printf("%d %d\n", a.fill(), b.fill());
  return 0;
}
