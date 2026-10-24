#include <cstdio>
#include <typeinfo>
// an enumeration's value argument spelled: __PRETTY_FUNCTION__ and the type information's name
enum class Color { Red, Green, Blue };
enum Plain { P0, P1 };
namespace ns { enum class K { a = 4, b }; }
template <auto V> struct X { static const char *name() { return __PRETTY_FUNCTION__; } };
template <Color C> struct Y { static const char *name() { return __PRETTY_FUNCTION__; } };
template <auto V> const char *f() { return __PRETTY_FUNCTION__; }
int main() {
  std::printf("%s\n%s\n", X<Color::Green>::name(), Y<Color::Blue>::name());
  std::printf("%s\n%s\n%s\n", f<P1>(), f<ns::K::b>(), f<(Color) 7>());
  std::printf("%s %s %s\n", typeid(X<Color::Red>).name(), typeid(Y<Color::Blue>).name(), typeid(X<P1>).name());
  std::printf("%s %s\n", typeid(X<ns::K::a>).name(), typeid(X<(Color) 9>).name());
  return 0;
}
