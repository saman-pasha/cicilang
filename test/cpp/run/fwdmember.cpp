// PERFECT FORWARDING INTO MEMBERS AND THROUGH TEMPORARIES (0.121): a member initializer `value(std::forward<B>(a)...)' copies an lvalue and moves an
// rvalue (the constructor was chosen on the RAW form of the argument and took the move constructor for every one -- libc++ 18's variant `__alt'
// moved the string out of a variant being copied); `decltype(x)' of a reference name keeps its reference; `std::forward<D>(x).m' of an rvalue is an
// xvalue and moves, of an lvalue copies; `std::move(x).m' is `std::move(x.m)'; the call of a temporary object converts its arguments
// (`std::hash<std::string>{}("hello")', `F{}("x")') as the call of a named one does.
#include <functional>
#include <string>
#include <type_traits>
#include <utility>
#include <cstdio>
struct S { int v; S(int x) : v(x) {} S(const S &o) : v(o.v) { std::printf("copy\n"); } S(S &&o) : v(o.v) { std::printf("move\n"); } };
template <class T> struct Wrap { T value; };
template <class... A> struct Alt {
  S value;
  template <class... B> Alt(int, B &&... a) : value(std::forward<B>(a)...) {}
};
template <class A> struct One {
  S value;
  One(A &&a) : value(std::forward<A>(a)) {}
};
template <class A> void viaforward(A &&x) { S s(std::forward<A>(x).value); std::printf("%d\n", s.v); }
template <class A> void viadecltype(A &&x) { using D = decltype(x); S s(std::forward<D>(x).value); std::printf("%d\n", s.v); }
void viamove(Wrap<S> &&x) { S s(std::move(x).value); std::printf("%d\n", s.v); }
size_t f(const std::string &s) { return s.size() * 1000 + (size_t) s[0]; }
struct F { size_t operator()(const std::string &s) const { return s.size() * 1000 + (size_t) s[0]; } };
int main() {
  S s(1);
  const S cs(2);
  std::printf("-- members\n");
  Alt<S> a(0, cs);
  Alt<S> b(0, s);
  Alt<S> c(0, S(3));
  Alt<S> d(0, std::move(s));
  One<const S &> e(cs);
  One<S &> g(s);
  std::printf("-- forward\n");
  Wrap<S> w{S(7)};
  viaforward(w);
  viadecltype(w);
  Wrap<S> w2{S(8)};
  viamove(static_cast<Wrap<S> &&>(w2));
  std::printf("-- decltype\n");
  auto lam = [](auto &&x) {
    std::printf("lref %d rref %d\n", (int) std::is_lvalue_reference<decltype(x)>::value, (int) std::is_rvalue_reference<decltype(x)>::value);
    std::printf("fwd lref %d rref %d\n", (int) std::is_lvalue_reference<decltype(std::forward<decltype(x)>(x))>::value, (int) std::is_rvalue_reference<decltype(std::forward<decltype(x)>(x))>::value);
  };
  lam(w);
  lam(Wrap<S>{S(9)});
  std::printf("-- temporaries\n");
  std::hash<std::string> h;
  F ff;
  std::printf("%zu %zu %zu %zu\n", f("hello"), ff("hello"), F{}("hello"), F()("hello"));
  std::printf("%d %d %d\n", (int) (h(std::string("hello")) == h("hello")), (int) (h("hello") == std::hash<std::string>{}("hello")), (int) (h("hello") == std::hash<std::string>()("hello")));
  return 0;
}
