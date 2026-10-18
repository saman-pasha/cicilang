// the vcall offsets of a virtual base's tables while each path is built (its construction tables) and in the complete object
#include <cstdio>
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
struct A { int a = 1; virtual int f() { return 1; } virtual int g() { return 2; } virtual ~A() {} };
struct B : virtual A { int b = 2; int f() override { return 20; } B() { tab("B.A", (A *) this, 5); std::printf("B %d %d\n", ((A *) this)->f(), ((A *) this)->g()); } };
struct C : virtual A { int c = 3; int g() override { return 30; } virtual int h() { return 4; } C() { tab("C.A", (A *) this, 5); std::printf("C %d %d\n", ((A *) this)->f(), ((A *) this)->g()); } };
struct D : B, C { int d = 4; int h() override { return 40; } };
struct E : virtual C { int e = 5; int f() override { return 50; } E() { tab("E.A", (A *) this, 5); tab("E.C", (C *) this, 5); } };
int main() {
  D d; tab("D.A", (A *) &d, 5); tab("D.C", (C *) &d, 3);
  std::printf("%d %d %d\n", ((A *) &d)->f(), ((A *) &d)->g(), ((C *) &d)->h());
  E e; tab("E.A", (A *) &e, 5); tab("E.C", (C *) &e, 6);
  std::printf("%d %d %d\n", ((A *) &e)->f(), ((A *) &e)->g(), ((C *) &e)->h());
  return 0;
}
