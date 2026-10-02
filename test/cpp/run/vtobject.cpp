// a variable template whose value is an object of an empty class, and an inline variable initialized by its instance
#include <cstdio>
namespace ns {
template <class D> struct closure {};
namespace det {
template <unsigned N> struct fn : closure<fn<N>> {
  int operator()(int x) const { return x + (int) N; }
};
}  // namespace det
template <unsigned N> inline constexpr auto elems = det::fn<N>{};
inline constexpr auto keys = elems<0>;
inline constexpr auto vals = elems<1>;
}  // namespace ns
int main() {
  std::printf("%d %d %d\n", ns::keys(5), ns::vals(5), ns::elems<3>(5));
  return 0;
}
