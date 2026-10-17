// A DIAMOND OVER A VIRTUAL BASE WITH NO TABLE (0.160): every class with a virtual base has a table, which carries the base's offset
#include <cstdio>
struct A { int a; A() : a(5) {} };
struct B : virtual A { int b; B() : b(1) { a += 1; } };
struct C : virtual A { int c; C() : c(2) { a += 10; } };
struct D : B, C { int d; D() : d(3) {} };
struct E : B { int e = 4; };
static int viaB(B &x) { return x.a + x.b; }
static int viaC(C *p) { return p->a + p->c; }
int main() {
  D d;
  B *pb = &d; C *pc = &d; A *pa = &d;
  std::printf("%d %d\n", d.a, d.b + d.c + d.d);
  pb->a = 20;
  std::printf("%d %d %d\n", d.a, pc->a, pa->a);
  std::printf("%d %d\n", viaB(d), viaC(&d));
  E e; std::printf("%d %d %d\n", e.a, viaB(e), e.e);
  B b; C c; std::printf("%d %d\n", viaB(b), viaC(&c));
  std::printf("%d %d %d %d\n", (int) sizeof(B), (int) sizeof(C), (int) sizeof(D), (int) sizeof(E));
  std::printf("%d %d\n", (int) ((char *) pa - (char *) &d), (int) ((char *) pc - (char *) &d));
  D d2 = d; std::printf("%d %d\n", d2.a, viaC(&d2));
  return 0;
}
