// a cast of a glvalue to its own class makes a temporary ([expr.static.cast]/4): moved from an xvalue, copied from an lvalue
#include <cstdio>
#include <tuple>
#include <type_traits>
#include <utility>
struct R {
  int id;
  R(int i) : id(i) { std::printf("make %d\n", id); }
  R(const R &o) : id(o.id + 10) { std::printf("copy %d\n", id); }
  R(R &&o) noexcept : id(o.id + 100) { o.id = -1; std::printf("move %d\n", id); }
  ~R() { std::printf("dtor %d\n", id); }
};
R get(int k) { return R(k); }
template <class... A> std::tuple<std::decay_t<A>...> *mk(A &&...a) {
  using G = std::tuple<std::decay_t<A>...>;
  return new G(static_cast<std::decay_t<A>>(std::forward<A>(a))...);
}
template <class A> R one(A &&a) { return static_cast<std::decay_t<A>>(std::forward<A>(a)); }
int main() {
  {
    auto *p = mk(get(1));
    std::printf("got %d\n", std::get<0>(*p).id);
    delete p;
  }
  std::printf("--\n");
  {
    R r = one(get(2));
    std::printf("got %d\n", r.id);
  }
  std::printf("--\n");
  {
    R s(3);
    R t = static_cast<R>(std::move(s));
    std::printf("got %d %d\n", s.id, t.id);
  }
  return 0;
}
