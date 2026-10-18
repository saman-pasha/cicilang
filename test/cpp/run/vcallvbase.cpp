// the vcall offsets of a virtual base's own table, read through its table pointer (the Itanium ABI 2.5.2)
#include <cstdio>
struct A { int a = 1; virtual int h() { return 2; } virtual ~A() {} };
struct J { virtual int g() { return 3; } virtual int g2() { return 4; } virtual ~J() {} };
struct D : A, virtual J { int d = 5; int g() override { return 50 + d; } };
struct W { int w = 6; virtual int m() { return 7; } virtual ~W() {} };
struct E : virtual W, virtual J { int e = 8; int m() override { return 80 + e; } int g2() override { return 81; } };
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  D d; E e;
  tab("D", &d, 3); tab("D.J", (J *) &d, 5); tab("E", &e, 4); tab("E.W", (W *) &e, 4); tab("E.J", (J *) &e, 5);
  std::printf("%d %d %d %d %d\n", ((J *) &d)->g(), ((J *) &d)->g2(), ((W *) &e)->m(), ((J *) &e)->g2(), ((J *) &e)->g());
  return 0;
}
