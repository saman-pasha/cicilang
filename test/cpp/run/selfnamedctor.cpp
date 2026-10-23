// a copy and a move constructor whose parameter names the class otherwise than by its plain name -- a template-id of its
// own template, S<T>, or an alias of the class -- are the class's copy and move
#include <cstdio>
#include <utility>
template <class T> struct S {
  T v;
  S(T x) : v(x) {}
  S(const S<T> &o) : v(o.v + 100) { std::printf("copy\n"); }
  S(S<T> &&o) : v(o.v + 1000) { std::printf("move\n"); }
  S &operator=(const S<T> &o) { v = o.v + 7; std::printf("assign\n"); return *this; }
};
struct A {
  typedef A Self;
  int v;
  A(int x) : v(x) {}
  A(const Self &o) : v(o.v + 50) { std::printf("A copy\n"); }
};
template <class T> S<T> make(T x) { return S<T>(x); }
int take(S<int> s) { return s.v; }
int takea(A a) { return a.v; }
A ret(A a) { return a; }
int main() {
  S<int> a(1);
  S<int> b = a;
  S<int> c = std::move(a);
  S<int> d = make(5);
  int t = take(b);
  c = d;
  std::printf("%d %d %d %d %d\n", b.v, c.v, d.v, t, a.v);
  A x(3);
  A y = x;
  int u = takea(y);
  A z = ret(x);
  std::printf("%d %d %d\n", y.v, u, z.v);
}
