#include <cstdio>
#include <utility>
#include <vector>
struct S { int a; };
struct P { int x; int y; };
void f(const S &s) { std::printf("copy %d\n", s.a); }
void f(S &&s) { std::printf("move %d\n", s.a); }
void g(S &s) { std::printf("lref %d\n", s.a); }
void g(S &&s) { std::printf("rref %d\n", s.a); }
void h(S s) { std::printf("value %d\n", s.a); }
void k(const P &p) { std::printf("kc %d\n", p.x); }
S make(int n) { S s{n}; return s; }
S pass(S s) { return std::move(s); }
template <class T> void t(T &&v) { f(std::forward<T>(v)); }
struct Box {
  void put(const S &s) { std::printf("box copy %d\n", s.a); }
  void put(S &&s) { std::printf("box move %d\n", s.a); }
};
int main() {
  S s{1};
  f(s); f(std::move(s)); f(S{2}); f(make(3));
  g(s); g(std::move(s)); g(S{4});
  h(s); h(std::move(s)); h(S{5});
  const S cs{6};
  f(cs); f(std::move(cs));
  S u = std::move(s); std::printf("u %d\n", u.a);
  S w = pass(S{7}); std::printf("w %d\n", w.a);
  t(s); t(std::move(s)); t(S{8});
  Box b; b.put(s); b.put(std::move(s)); b.put(S{9});
  P p{1, 2}; k(p); k(std::move(p)); k(P{3, 4});
  std::vector<S> v; v.push_back(S{10}); v.push_back(s); v.push_back(std::move(s));
  std::printf("%d\n", (int) v.size());
  return 0;
}
