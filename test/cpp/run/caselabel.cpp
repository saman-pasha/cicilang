// A case label is a constant expression ([stmt.switch]/2), desugared as any: a qualified enumerator of a scoped enum in
// a namespace, a class's static constant, a constexpr call. libc++ 18 writes `case __format_spec::__type::__default:'.
#include <cstdio>
namespace ns {
enum class Ty : unsigned char { def = 0, bin, oct, hex };
struct K { static constexpr int lim = 7; };
constexpr int twice(int x) { return 2 * x; }
}
template <class T> struct H { static constexpr T top = 40; };
int f(ns::Ty t) {
  switch (t) {
  case ns::Ty::def: return 1;
  case ns::Ty::bin:
  case ns::Ty::oct: return 2;
  default: return 3;
  }
}
int g(int x) {
  switch (x) {
  case ns::K::lim: return 9;
  case ns::twice(5): return 10;
  case H<int>::top: return 40;
  default: return 0;
  }
}
int main() {
  std::printf("%d %d %d %d | %d %d %d %d\n", f(ns::Ty::def), f(ns::Ty::bin), f(ns::Ty::oct), f(ns::Ty::hex), g(7), g(10), g(40), g(3));
  return 0;
}
