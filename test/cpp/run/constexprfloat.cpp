// floating arithmetic in a constant evaluation (0.258): float and double values, their operations and comparisons,
// conversions at a parameter, a return and a store, constexpr floating objects, an infinity, a lambda's constant
#include <cstdio>
constexpr double area(double r) { return 3.14159 * r * r; }
static_assert(area(2.0) > 12.5 && area(2.0) < 12.6);
constexpr float f1 = 0.1f + 0.2f;
static_assert(f1 == 0.3f);
static_assert(0.1 + 0.2 != 0.3);
constexpr int i = static_cast<int>(2.9);
static_assert(i == 2);
constexpr double third = 1.0 / 3;
static_assert(third * 3 == 1.0);
constexpr double sum10() { double s = 0; for (int k = 0; k < 10; ++k) s += 0.1; return s; }
static_assert(sum10() != 1.0 && sum10() > 0.99);
constexpr float fsum() { float s = 0; for (int k = 0; k < 10; k++) s += 0.1f; return s; }
static_assert(fsum() > 1.0f);
constexpr int trunc(double x) { return x; }
static_assert(trunc(-2.7) == -2 && trunc(3.99) == 3);
constexpr double mix(int a, float b) { return a / 2 + b * 2; }
static_assert(mix(5, 0.25f) == 2.5);
constexpr bool zero(double x) { return !x; }
static_assert(zero(0.0) && !zero(0.5));
struct V { double x, y; constexpr double dot(const V &o) const { return x * o.x + y * o.y; } };
constexpr V a{1.5, 2.0}, b{2.0, 0.25};
static_assert(a.dot(b) == 3.5);
constexpr double huge() { double x = 1e308; return x * 10; }
static_assert(huge() > 1e308);
int lam() { constexpr double k = 2.5; constexpr float q = 0.5f; auto l = [] { return k * 2 + q; }; static_assert(l() == 5.5); return (int)l(); }
int main() { std::printf("%.17g %.9g %d %.17g %.17g %.9g %d %d %g %d %g %d\n", area(2.0), (double)f1, i, third, sum10(), (double)fsum(), trunc(-2.7), trunc(3.99), mix(5, 0.25f), (int)zero(0.0), a.dot(b), lam()); }
