// the arguments of a function called through a tuple, as std::thread's proxy calls it: moved into the by-value parameters
#include <cstdio>
#include <functional>
#include <memory>
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
template <class F, class... A, std::size_t... I> void exec(std::tuple<std::unique_ptr<int>, F, A...> &t, std::index_sequence<I...>) {
  std::invoke(std::move(std::get<1>(t)), std::move(std::get<I + 2>(t))...);
}
template <class F, class... A> void start(F &&f, A &&...a) {
  std::unique_ptr<int> u(new int(7));
  using G = std::tuple<std::unique_ptr<int>, std::decay_t<F>, std::decay_t<A>...>;
  std::unique_ptr<G> p(new G(std::move(u), std::forward<F>(f), std::forward<A>(a)...));
  std::printf("built\n");
  exec(*p, std::index_sequence_for<A...>());
  std::printf("ran\n");
}
int main() {
  auto f = [](R r) { std::printf("in %d\n", r.id); };
  start(f, get(5));
  std::printf("--\n");
  R k(6);
  start(f, k);
  return 0;
}
