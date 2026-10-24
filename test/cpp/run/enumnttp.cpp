#include <cstdio>
#include <type_traits>
// an enumeration's value as a template argument keeps its type ([temp.arg.nontype]/1): `X<Color::Red>' and `X<0>' of a
// placeholder are two classes, `decltype' of the value is the enumeration, and a written parameter of the enum takes it
enum class Color { Red, Green, Blue };
enum Plain { P0, P1 };
template <auto V> struct X { static constexpr auto v = V; static int id() { return sizeof(V); } };
template <Color C> struct Y { static constexpr Color c = C; };
template <auto V> int f() { return std::is_same_v<decltype(V), Color> ? 1 : std::is_same_v<decltype(V), Plain> ? 2 : 3; }
int main() {
  std::printf("%d\n", std::is_same_v<X<Color::Red>, X<0>>);
  std::printf("%d\n", std::is_same_v<decltype(X<Color::Green>::v), const Color>);
  std::printf("%d %d %d\n", f<Color::Blue>(), f<P1>(), f<1>());
  std::printf("%d\n", (int) Y<Color::Blue>::c);
  std::printf("%d %d\n", std::is_same_v<X<P1>, X<1>>, std::is_same_v<X<P1>, X<P1>>);
  return 0;
}
