// a member class template defined out of its class, whose default member initializer names its own alias inside an
// alias template's argument: the shape of libc++'s transform_view::__sentinel (`sentinel_t<_Base> __end_ = sentinel_t<_Base>();')
#include <cstdio>
#include <type_traits>
namespace rg {
struct end_fn {
  template <class T> auto operator()(T &t) const -> decltype(t.end()) { return t.end(); }
};
inline constexpr end_fn end{};
template <class T> T &&declv();
template <class R> using sent_t = decltype(rg::end(declv<R &>()));
}  // namespace rg
struct vec {
  int n;
  int end() const { return n + 3; }
};
template <class V> struct tv {
  V v;
  template <bool> class sent;
  sent<true> end() const { return sent<true>(rg::end(v)); }
};
template <class V> template <bool C> class tv<V>::sent {
  using Base = std::conditional_t<C, const V, V>;
  rg::sent_t<Base> end_ = rg::sent_t<Base>();
public:
  sent() = default;
  explicit sent(rg::sent_t<Base> e) : end_(e) {}
  rg::sent_t<Base> base() const { return end_; }
};
int main() {
  tv<vec> t{vec{4}};
  tv<vec>::sent<true> s0;
  std::printf("%d %d\n", t.end().base(), s0.base());
  return 0;
}
