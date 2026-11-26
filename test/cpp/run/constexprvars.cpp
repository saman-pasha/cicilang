// constexpr variables (1.6.22): one whose initializer folds is a constant, and one whose initializer calls a function that
// is not constexpr, or whose evaluation reaches a trap, is refused (the driver gate); a const variable and a plain one
// over such a call keep their run-time initialization, and so does a constexpr one whose fold the evaluator does not take
// (`k(3) / 4.0'). A fold binds each argument as its parameter's type and gives the return type's value: `kd(3)' over a
// double parameter was `3 / 4', 0, and `f8(200)' over a signed char 201
#include <cstdio>
constexpr int k(int x) { return x * 2; }
constexpr int f(int x) { return x > 0 ? x : (__builtin_trap(), 0); }
int h() { return 3; }
constexpr double kd(double x) { return x / 4; }
constexpr int f8(signed char c) { return c + 1; }
constexpr unsigned fu(unsigned short s) { return s * 2u; }
constexpr int fc(double x) { return x * 2; }
constexpr signed char r8(int x) { return x; }
constexpr bool rb(int x) { return x; }
constexpr unsigned char ru(int x) { return x + 1; }
constexpr int two(int a, short b) { return a + b; }
constexpr int fbo(bool b) { return b + 1; }
constexpr double fdl(long double x) { return x / 3; }
constexpr float rfl(double x) { return x / 3; }
constexpr int g = k(21);
constexpr int fg = f(5);
const int c = k(2);
const int ch = h();
int r = h();
constexpr double dd = k(3) / 4.0;
constexpr double de = kd(3);
const double ce = kd(3);
constexpr int d8 = f8(200);
constexpr unsigned du = fu(70000);
constexpr int dc = fc(1.25);
constexpr int dr = r8(200);
constexpr int db = rb(7);
constexpr int dru = ru(300);
constexpr int dtwo = two(1, 70000);
constexpr int dbo = fbo(9);
constexpr double ddl = fdl(1);
constexpr double drfl = rfl(1);
static_assert(d8 == -55 && du == 8928 && dr == -56 && db == 1 && dru == 45 && dtwo == 4465, "converted");
int main() {
  constexpr int lg = k(4);
  constexpr int ld8 = f8(200);
  constexpr double lde = kd(3);
  static_assert(g == 42 && fg == 5 && lg == 8 && ld8 == -55, "folded");
  std::printf("%d %d %d %d %d %d\n", g, fg, c, ch, r, lg);
  std::printf("%g %g %g %g %.17g\n", dd, de, ce, lde, ddl);
  std::printf("%d %u %d %d %d %d %d %d %d\n", d8, du, dc, dr, db, dru, dtwo, ld8, dbo);
  std::printf("%.17g\n", drfl);
  return 0;
}
