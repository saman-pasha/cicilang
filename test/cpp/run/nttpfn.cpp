// A function given to a value parameter of a placeholder or a pointer type is its address ([temp.param]/10,
// [temp.arg.nontype]/1; 0.206): decltype of the parameter is the pointer, X<f> and X<&f> are one instance, and a
// temporary of the instance is made from its template-id -- libc++ 21's std::not_fn<f>() is written so.
#include <cstdio>
#include <type_traits>
template <auto F> struct NF {
  template <class... A> constexpr auto operator()(A &&...a) const -> decltype(!F(a...)) { return !F(a...); }
};
template <auto F> constexpr auto nf() { return NF<F>(); }
template <auto F> constexpr int kind() { return std::is_pointer_v<decltype(F)> ? 1 : std::is_function_v<decltype(F)> ? 2 : 3; }
template <bool (*G)(int)> struct PG {
  static constexpr bool ptr = std::is_pointer_v<decltype(G)>;
  static bool call(int x) { return G(x); }
};
constexpr bool is_odd(int x) { return x % 2 != 0; }
bool is_big(int x) { return x > 100; }
int main() {
  NF<is_odd> direct;
  NF<is_odd> t = NF<is_odd>();
  std::printf("direct %d %d\n", (int) direct(4), (int) t(3));
  auto even = nf<is_odd>();
  auto small = nf<&is_big>();
  std::printf("made %d %d %d %d\n", (int) even(4), (int) even(3), (int) small(7), (int) small(700));
  std::printf("kind %d %d %d\n", kind<is_odd>(), kind<&is_odd>(), (int) std::is_same_v<NF<is_odd>, NF<&is_odd>>);
  std::printf("pointer %d %d %d\n", (int) PG<is_big>::ptr, (int) PG<is_big>::call(500), (int) PG<&is_odd>::call(5));
}
