// C++14's complex literals ([complex.literals]; 0.179): `3i', `3il', `3if' through `using namespace std::complex_literals', typed
// std::complex<double>, <long double> and <float>, and their arithmetic -- at C++23 over libc++ 18 <complex> was read only up to
// unique_ptr and its literal operators were lost: our <stddef.h> left glibc's `__need_size_t' defined, so libc++'s <stddef.h>
// never declared ::nullptr_t and <cstddef> stopped at its #error
#include <complex>
#include <cstdio>
#include <typeinfo>
using namespace std::complex_literals;
int main() {
  std::complex<double> z = 1.0 + 2.0i;
  auto w = z * 3i;
  std::complex<float> f = 1.5if;
  std::printf("%g %g %g %g %g\n", z.real(), z.imag(), w.real(), w.imag(), (double)f.imag());
  auto e = 3i; auto g = 3il; auto h = 3if;
  std::printf("%s %s %s\n", typeid(e).name(), typeid(g).name(), typeid(h).name());
  std::printf("%g %g %g\n", e.imag(), (double)g.imag(), (double)h.imag());
  return 0;
}
