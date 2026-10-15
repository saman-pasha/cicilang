// A constructor TEMPLATE callable with no argument is a default constructor ([class.default.ctor]/1): std::tuple's,
// and one of the program's own. A class holding one has its implicit default constructor, so a local of it is built
// over whatever the stack held: its default member initializers run and its tuple's elements are constructed.
#include <string>
#include <tuple>
#include <type_traits>
#include <cstdio>
struct Parser { int precision{-1}; char fill{' '}; };
struct Elem { Parser p; };
struct A {
  template <class T = int, std::enable_if_t<std::is_integral_v<T>, int> = 0> A() : v(42) {}
  int v;
};
template <class... Ts> struct Holder { std::tuple<Ts...> u; int n = 7; };
struct Derived : Holder<Elem, Elem> {};
struct Own { A a; int k = 3; };
__attribute__((noinline)) void dirty() { volatile char b[1024]; for (int i = 0; i < 1024; i++) b[i] = (char) 0x5a; }
__attribute__((noinline)) void show() {
  Holder<Elem, std::string> h;
  Derived d;
  Own o;
  std::printf("%d %d %d '%s'\n", std::get<0>(h.u).p.precision, (int) std::get<0>(h.u).p.fill, h.n, std::get<1>(h.u).c_str());
  std::printf("%d %d | %d %d\n", std::get<1>(d.u).p.precision, d.n, o.a.v, o.k);
}
int main() { dirty(); show(); return 0; }
