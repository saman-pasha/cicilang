// GNU's imaginary literal where no literal operator `i' is visible -- a _Complex int, double, float, and `3if' a _Complex int,
// `3il' a _Complex long, `2.0il' a _Complex long double -- and <complex>'s where a using makes one visible, in a block or in a
// namespace, to its end (0.179): the type information of a complex type, `Ci', and of a library class that libc++ does not
// export, std::complex<double>
#include <complex>
#include <cstdio>
#include <typeinfo>
namespace inner {
using namespace std::complex_literals;
inline auto z() { return 3i; }
}
int main() {
  auto e = 3i; auto f = 2.0i; auto g = 1.5if;
  std::printf("%s %s %s\n", typeid(e).name(), typeid(f).name(), typeid(g).name());
  auto p = 3if; auto q = 3il; auto r = 2.0il;
  std::printf("%s %s %s\n", typeid(p).name(), typeid(q).name(), typeid(r).name());
  {
    using namespace std::complex_literals;
    auto h = 3i; auto k = 2.0i; auto m = 1.5if;
    std::printf("%s %s %s\n", typeid(h).name(), typeid(k).name(), typeid(m).name());
  }
  auto t = 3i; auto w = inner::z();
  std::printf("%s %s %g\n", typeid(t).name(), typeid(w).name(), w.imag());
  const std::complex<double> *pc = nullptr; _Complex double *pg = nullptr;
  std::printf("%s %s\n", typeid(pc).name(), typeid(pg).name());
  return 0;
}
