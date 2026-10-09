// <complex> and <cmath> (0.117): complex<double> and complex<float> arithmetic, real / imag, abs, arg, norm, conj, polar, the
// comparisons, the compound assignments, and the floating functions of <cmath> the template reaches. Reads libc++'s `operator"" if'
// (a keyword as the literal operator's suffix) and its out-of-class members.
#include <complex>
#include <cmath>
#include <cstdio>
int main() {
  std::complex<double> a(1, 2), b(3, -1);
  auto c = a * b + std::conj(a);
  std::printf("%g %g %g\n", c.real(), c.imag(), std::abs(b));
  auto q = a / b, s = a - b;
  std::printf("%.4f %.4f %g %g\n", q.real(), q.imag(), s.real(), s.imag());
  std::printf("%g %.4f %.4f\n", std::norm(b), std::arg(a), std::abs(std::polar(2.0, 0.5)));
  std::complex<double> z(0, 0);
  z += a; z *= b; z -= 1.0; z /= 2.0;
  std::printf("%g %g %d %d\n", z.real(), z.imag(), (int)(a == a), (int)(a != b));
  std::complex<float> f(1.5f, -0.5f), g(2.0f, 1.0f);
  auto h = f * g;
  std::printf("%g %g %g\n", h.real(), h.imag(), std::abs(g));
  std::printf("%.4f %.4f %.4f %.4f\n", std::sin(1.0), std::exp(2.0), std::pow(2.0, 0.5), std::atan2(1.0, 2.0));
  std::printf("%d %d %.1f %.1f\n", (int)std::lround(2.5), (int)std::floor(-1.5), std::fmod(7.5, 2.0), std::hypot(3.0, 4.0));
  return 0;
}
