// Value template arguments of their parameters' types (0.199): a placeholder's by the argument's own, decltype of a static and of a
// constant declared with auto, a size_t argument past an int's range
#include <cstdio>
#include <type_traits>
struct P { static constexpr auto v = 5; static constexpr auto c = 'q'; static const auto u = 7u; };
constexpr auto g = 5;
const auto h = 'z';
template <int N> struct Y { static constexpr auto v = N; static constexpr int w = N; };
template <unsigned N> auto f() { return N; }
template <class T, T V> struct IC { static constexpr T value = V; using type = T; constexpr operator T() const { return V; } };
template <auto N> struct X { static constexpr auto v = N; };
template <auto N> auto fa() { return N; }
int main() {
  std::printf("%d %d %d %d %d\n", (int) std::is_same_v<decltype(P::v), const int>, (int) std::is_same_v<decltype(P::c), const char>,
              (int) std::is_same_v<decltype(P::u), const unsigned>, (int) std::is_same_v<decltype(g), const int>, (int) std::is_same_v<decltype(h), const char>);
  std::printf("%d %d %d %d\n", (int) std::is_same_v<decltype(Y<5>::v), const int>, (int) std::is_same_v<decltype(Y<5>::w), const int>,
              (int) std::is_same_v<decltype(f<5>()), unsigned>, (int) std::is_same_v<decltype(IC<char, 'a'>::value), const char>);
  std::printf("%d %d %d %d\n", (int) std::is_same_v<decltype(X<'a'>::v), const char>, (int) std::is_same_v<decltype(fa<'c'>()), char>,
              (int) std::is_same_v<decltype(fa<5u>()), unsigned>, (int) std::is_same_v<X<'a'>, X<97>>);
  std::printf("%d %d %d %u\n", (int) sizeof(X<'a'>::v), (int) sizeof(fa<'c'>()), (int) sizeof(f<5>()), f<4000000000u>());
}
