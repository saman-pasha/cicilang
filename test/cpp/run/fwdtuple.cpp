// perfect forwarding into a member and into std::tuple: an xvalue moves, an lvalue copies
#include <cstdio>
#include <tuple>
#include <utility>
struct R {
  int id;
  R(int i) : id(i) { std::printf("make %d\n", id); }
  R(const R &o) : id(o.id + 10) { std::printf("copy %d\n", id); }
  R(R &&o) noexcept : id(o.id + 100) { o.id = -1; std::printf("move %d\n", id); }
  ~R() { std::printf("dtor %d\n", id); }
};
R make(int k) { return R(k); }
template <class T> struct Leaf {
  T v;
  template <class U> Leaf(U &&u) : v(std::forward<U>(u)) {}
};
int main() {
  { R a(1); Leaf<R> l1(std::move(a)); std::printf("l1 %d\n", l1.v.id); }
  std::printf("--\n");
  { Leaf<R> l2(make(2)); std::printf("l2 %d\n", l2.v.id); }
  std::printf("--\n");
  { R a(3); Leaf<R> l3(a); std::printf("l3 %d\n", l3.v.id); }
  std::printf("--\n");
  { std::tuple<R> t(make(4)); std::printf("t %d\n", std::get<0>(t).id); }
  std::printf("--\n");
  { R a(5); std::tuple<R> t(std::move(a)); std::printf("t %d\n", std::get<0>(t).id); }
  return 0;
}
