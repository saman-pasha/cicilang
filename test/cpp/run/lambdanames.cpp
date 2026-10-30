// 0.236: a closure's type information is named as clang++ names it -- `$_N' in a function no other unit defines,
// numbered in the order made (one at file scope by the count of all before it), `Ul <parameters> E [n] _' in an inline
// function, a member defined in its class, a template's instance, an inline variable and a static data member, a
// closure's own call operator a local name of its own
#include <cstdio>
#include <typeinfo>
#define P(x) std::printf("%s\n", typeid(x).name())
inline auto lam = [](int) { return 1; };
auto glam = [](double, char) { return 2; };
namespace ns { auto nl = [] {}; }
struct K {
  int f() { auto l = [this] { return 3; }; P(l); return l(); }
  static inline auto si = [](long) { return 0; };
};
template <class T> struct TC { void m() { auto l = [] {}; P(l); } };
template <class T> void tf(T) { auto l = [] {}; P(l); }
template <class F> void show(F) { P(F); }
inline void ilf() {
  auto a = [] { auto b = [] {}; P(b); return 0; }; P(a); a();
  auto g = [](auto x) { return x; }; P(g);
  auto h = []<class T>(T x) { return x; }; P(h);
  auto v = [](auto... x) { return sizeof...(x); }; P(v);
  auto c1 = [](int) {}; auto c2 = [](int) {}; P(c1); P(c2);
}
void plf() { auto a = [] { auto b = [] {}; P(b); return 0; }; P(a); a(); }
int main() {
  auto a = [] {};
  auto b = [](int x) { return x; };
  auto c = [](auto x) { return x; };
  P(a); P(b); P(c); P(lam); P(glam); P(ns::nl);
  K{}.f(); P(K::si);
  TC<int>{}.m(); TC<double>{}.m(); tf(1); tf('c');
  show([] {}); show([](long) {});
  ilf(); plf();
  return b(0);
}
