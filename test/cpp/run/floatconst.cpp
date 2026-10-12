// a floating static data member initialized in its class is its own definition, linkonce as an integral one is: a
// constexpr double, float and long double, an inline double written to, a quotient, a class template's members over its
// parameter, one whose address is taken; one whose initializer does not fold (another static, a constexpr call, a
// private one) is assigned before main; and a negative zero in a constant keeps its sign, a member's and a global's
#include <cstdio>
constexpr double sq(double x) { return x * x; }
struct S {
  static constexpr double a = 1.5;
  static constexpr float b = 2.25f;
  static inline double c = 3.5;
  static constexpr long double d = 4.5L;
  static constexpr double e = 1.0 / 3.0;
  static constexpr double z = -0.0;
  static constexpr int i = 7;
  static constexpr double tau = 2 * a;
  static constexpr double s = sq(1.5);
  static inline float h = (float) tau / 4;
private:
  static constexpr double hidden = a / 2;
public:
  static double get() { return hidden; }
};
template <class T> struct U { static constexpr T v = T(0.25); static constexpr T w = -T(1) / 8; static constexpr T x = v * v; };
constexpr double cz = -0.0;
const double *addr() { return &S::a; }
int main() {
  std::printf("%g %g %g %Lg %.17g %d\n", S::a, (double) S::b, S::c, S::d, S::e, S::i);
  std::printf("%g %g %g %g\n", U<double>::v, (double) U<float>::w, U<double>::x, *addr());
  std::printf("%g %g %g %g\n", S::tau, S::s, (double) S::h, S::get());
  S::c += 1.0;
  std::printf("%g %g %g %g %g\n", S::c, S::z, 1.0 / S::z, cz, 1.0 / cz);
  return 0;
}
