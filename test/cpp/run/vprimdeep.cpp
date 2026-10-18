// deeper: a primary virtual base two classes down, beside a later virtual base, written after a plain base, beside an empty base
#include <cstdio>
#include <typeinfo>
struct I { virtual int f() { return 1; } virtual ~I() {} };
struct X : virtual I { int x = 2; int f() override { return 20 + x; } };
struct Y : X { int y = 3; };
struct YY : Y { int yy = 4; int f() override { return 400 + yy; } };
struct J { int j = 5; virtual int h() { return 50; } virtual ~J() {} };
struct M : X, virtual J { int m = 6; int h() override { return 60 + m; } };
struct E {};
struct XE : E, virtual I { int e = 7; int f() override { return 70 + e; } };
struct XF : virtual I, E { int e2 = 8; };
struct K { int k1 = 9; };
struct XK : K, virtual I, E { int k2 = 10; int f() override { return 100 + k2; } };
struct T : XK, X { int t = 11; int f() override { return 110 + t; } };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu %zu %zu %zu %zu\n", sizeof(YY), sizeof(M), sizeof(XE), sizeof(XF), sizeof(XK), sizeof(T), sizeof(Y));
  YY yy; M m; XE xe; XF xf; XK xk; T t;
  std::printf("YY: I %ld yy %ld f %d %d\n", off((I *) &yy, &yy), off(&yy.yy, &yy), yy.f(), ((I *) &yy)->f());
  std::printf("M: I %ld J %ld m %ld f %d h %d %d\n", off((I *) &m, &m), off((J *) &m, &m), off(&m.m, &m), ((I *) &m)->f(), m.h(), ((J *) &m)->h());
  std::printf("XE: I %ld e %ld f %d; XF: I %ld e2 %ld f %d\n", off((I *) &xe, &xe), off(&xe.e, &xe), ((I *) &xe)->f(), off((I *) &xf, &xf), off(&xf.e2, &xf), ((I *) &xf)->f());
  std::printf("XK: I %ld K %ld k2 %ld f %d\n", off((I *) &xk, &xk), off((K *) &xk, &xk), off(&xk.k2, &xk), ((I *) &xk)->f());
  std::printf("T: I %ld XK %ld X %ld t %ld f %d %d %d\n", off((I *) &t, &t), off((XK *) &t, &t), off((X *) &t, &t), off(&t.t, &t), ((I *) &t)->f(), ((X *) &t)->f(), ((XK *) &t)->f());
  tab("YY", &yy, 5); tab("M", &m, 6); tab("XE", &xe, 5); tab("XK", &xk, 5); tab("T", &t, 5); tab("T.X", (X *) &t, 5);
  std::printf("%s %s %s\n", typeid(*(I *) &m).name(), typeid(*(I *) &t).name(), typeid(*(J *) &m).name());
  std::printf("dc %d %d\n", dynamic_cast<M *>((J *) &m) == &m, dynamic_cast<T *>((I *) &t) == &t);
  return 0;
}
