// two namespaces of ONE innermost name each declare `fn', as libc++'s ranges::__transform and
// ranges::views::__transform do: each keyed apart, and `imp::fn{}' written relative to its own namespace
#include <cstdio>
namespace lib {
namespace r {
namespace imp { struct fn { int operator()(int a, int b, int c) const { return a + b + c; } }; }
inline namespace cpo { inline constexpr auto apply = imp::fn{}; }
namespace v {
namespace imp { struct fn { int operator()(int a) const { return a * 10; } }; }
inline namespace cpo { inline constexpr auto apply = imp::fn{}; }
int twice(int x) { return imp::fn{}(x) * 2; }
}
int once(int x) { return imp::fn{}(x, 0, 0); }
}
}
int main() {
  std::printf("%d %d\n", lib::r::apply(1, 2, 3), lib::r::v::apply(4));
  std::printf("%d %d\n", lib::r::v::twice(5), lib::r::once(6));
  return 0;
}
