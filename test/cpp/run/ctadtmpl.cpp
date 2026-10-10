// A template template parameter called, `C(args)', deduces its template's arguments ([over.match.class.deduct]), in a
// decltype and in a function's body -- how ranges::to<std::vector>(r) finds its container.
#include <cstdio>
#include <utility>
#include <vector>
template <class T> struct Box { T v; Box(T x) : v(x) {} };
template <template <class...> class C, class R> struct Deduce { using type = decltype(C(std::declval<R>())); };
template <template <class...> class C, class R> auto make(R &&r) { return C(std::forward<R>(r)); }
int main() {
  std::vector<int> a{1, 2, 3};
  typename Deduce<std::vector, std::vector<int> &>::type w = a;
  auto b = make<Box>(7);
  auto c = make<std::vector>(a);
  std::printf("%d %d %d\n", (int) w.size(), b.v, (int) c.size());
  return 0;
}
