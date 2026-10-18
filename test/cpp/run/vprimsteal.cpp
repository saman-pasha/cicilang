// a class over a primary virtual base through a virtual base (clang steals it) and over two nearly empty virtual bases: calls only
#include <cstdio>
struct I { virtual int f() { return 1; } virtual ~I() {} };
struct X : virtual I { int x = 2; int f() override { return 20 + x; } };
struct D : virtual X { int d = 3; };
struct J { virtual int g() { return 4; } virtual ~J() {} };
struct XJ : virtual I, virtual J { int v = 5; int g() override { return 50 + v; } };
int main() {
  D d; XJ xj;
  std::printf("D %d %d %d\n", d.f(), ((I *) &d)->f(), ((X *) &d)->f());
  std::printf("XJ %d %d %d\n", ((I *) &xj)->f(), ((J *) &xj)->g(), xj.g());
  I *p = new D; std::printf("new D %d\n", p->f()); delete p;
  return 0;
}
