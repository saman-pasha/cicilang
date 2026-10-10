// A free function DEFINITION's trailing return type is its result, a `decltype' over the parameters
// among them ([dcl.fct]/2), and is part of its SFINAE ([temp.deduct]/8). The definition took the
// first return's type, decayed: `first(v) = 10' wrote into a temporary, and the overload that
// `-> decltype(t.foo())' should have dropped for an int stayed and was refused (0.127)
#include <cstdio>
#include <utility>
#include <vector>

struct V { int a[3] = {1, 2, 3}; int &operator[](int i) { return a[i]; } };
auto first(V &v) -> decltype(v[0]) { return v[0]; }
template <class T> auto at(T &t, int i) -> decltype(t[i]) { return t[i]; }
template <class T> auto back(T &c) -> decltype(c.back()) { return c.back(); }

struct A { int foo() const { return 1; } };
template <class T> auto call(const T &t, int) -> decltype(t.foo()) { return t.foo(); }
template <class T> int call(const T &, long) { return -1; }
template <class T> auto deref(T &&t, int) -> decltype(*std::declval<T>()) { return *t; }
template <class T> int deref(T &&, long) { return -2; }
template <class T> auto size_of(const T &c, int) -> decltype(c.size(), 0) { return (int) c.size(); }
template <class T> int size_of(const T &, long) { return -3; }

template <class... Ts> auto sum(Ts... ts) -> decltype((ts + ...)) { return (ts + ...); }
auto twice(int x) -> decltype(x * 2) { return x * 2; }

int main() {
  V v;
  first(v) = 10;
  at(v, 1) = 20;
  std::printf("%d %d %d\n", v.a[0], v.a[1], v.a[2]);
  std::vector<int> w{4, 5, 6};
  back(w) = 60;
  at(w, 0) += 40;
  std::printf("%d %d %d\n", w[0], w[1], w[2]);
  int n = 9;
  std::printf("%d %d\n", call(A{}, 0), call(5, 0));
  std::printf("%d %d\n", deref(&n, 0), deref(5, 0));
  std::printf("%d %d\n", size_of(w, 0), size_of(n, 0));
  std::printf("%d %.1f %d\n", sum(1, 2, 3), sum(1.5, 2), twice(21));
  return 0;
}
