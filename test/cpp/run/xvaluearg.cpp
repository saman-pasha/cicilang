// an xvalue handed to a by-value class parameter is moved from: static_cast<R &&>(x), std::forward, std::invoke
#include <cstdio>
#include <functional>
#include <tuple>
#include <utility>
struct R {
  int id;
  R(int i) : id(i) { std::printf("make %d\n", id); }
  R(const R &o) : id(o.id + 10) { std::printf("copy %d\n", id); }
  R(R &&o) noexcept : id(o.id + 100) { o.id = -1; std::printf("move %d\n", id); }
  ~R() { std::printf("dtor %d\n", id); }
};
void g(R r) { std::printf("g %d\n", r.id); }
template <class F, class A> void fwd(F &&f, A &&a) { static_cast<F &&>(f)(static_cast<A &&>(a)); }
int main() {
  auto f = [](R r) { std::printf("in %d\n", r.id); };
  { R a(1); std::invoke(f, std::move(a)); }
  std::printf("--\n");
  { R b(2); f(std::move(b)); }
  std::printf("--\n");
  { R c(3); f(static_cast<R &&>(c)); }
  std::printf("--\n");
  { std::tuple<R> t(4); std::invoke(f, std::move(std::get<0>(t))); }
  std::printf("--\n");
  { R d(5); fwd(f, std::move(d)); }
  std::printf("--\n");
  { R e(6); fwd(g, std::move(e)); }
  std::printf("--\n");
  { R h(7); g(static_cast<R &&>(h)); }
  return 0;
}
