// the names a class finds through the bases it writes, its primary virtual base stolen: a non-virtual member the base hides, a static,
// a type, a data member, and calls of each
#include <cstdio>
struct I { virtual int f() { return 1; } int g() { return 2; } static int s() { return 3; } typedef int T; enum { K = 4 }; virtual ~I() {} };
struct X : virtual I { int x = 5; int g() { return 50 + x; } static int s() { return 60; } int f() override { return 70 + x; } };
struct D : virtual X { int d = 6; int dd() { return g() + s() + f() + K; } T t() { return x + d; } };
struct D2 : virtual X, virtual I { int d2 = 7; int dd() { return g() + s() + f() + K; } };
int main() {
  D d; D2 d2;
  std::printf("D %d %d %d %d %d %d\n", d.g(), d.s(), d.f(), d.dd(), d.t(), d.I::g());
  std::printf("D2 %d %d %d %d\n", d2.g(), d2.s(), d2.f(), d2.dd());
  D *pd = &d; X *px = pd; I *pi = pd;
  std::printf("ptr %d %d %d %d\n", pd->g(), px->g(), pi->g(), pi->f());
  return 0;
}
