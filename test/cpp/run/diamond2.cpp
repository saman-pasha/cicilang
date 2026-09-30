// the diamond through each side: a write through one path is seen through the other (0.110)
#include <cstdio>
struct A { virtual ~A() {} virtual int f() { return 1; } int a = 10; };
struct B : virtual A { int f() override { return 2; } int b = 20; };
struct C : virtual A { int c = 30; int getA() { return a; } };
struct D : B, C { int d = 40; };
static int viaA(A &x) { return x.a + x.f(); }
static int viaC(C *p) { return p->a + p->c; }
int main() {
  D d;
  B *pb = &d; C *pc = &d;
  pb->a = 11;
  std::printf("%d %d %d\n", pc->a, pc->getA(), d.a);
  std::printf("%d %d\n", viaA(d), viaC(&d));
  C c; std::printf("%d %d\n", viaC(&c), c.getA());
  std::printf("%d\n", (int) (sizeof(D) > sizeof(B)));
  return 0;
}
