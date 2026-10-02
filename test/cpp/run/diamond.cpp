// a DIAMOND: one virtual base reached through two bases is one sub-object, reached through the tables' vbase offsets, built once and destroyed last, the final overriders from either path (0.110)
#include <cstdio>
#include <typeinfo>
static int made = 0, gone = 0;
struct A { int a; A() : a(5) { made++; std::printf("A()\n"); } virtual ~A() { gone++; std::printf("~A\n"); } virtual int f() { return a; } virtual int g() { return 100; } };
struct B : virtual A { int b; B() : b(1) { std::printf("B() a=%d\n", a); } ~B() { std::printf("~B\n"); } int f() override { return a + b; } };
struct C : virtual A { int c; C() : c(2) { a += 10; std::printf("C() a=%d\n", a); } ~C() { std::printf("~C\n"); } int g() override { return a * 2; } };
struct D : B, C { int d; D() : d(3) { std::printf("D() a=%d\n", a); } ~D() { std::printf("~D\n"); } };
int main() {
  {
    D x;
    A *pa = &x; B *pb = &x; C *pc = &x;
    std::printf("%d %d %d %d\n", pa->f(), pa->g(), pb->g(), pc->f());
    std::printf("%s %s\n", typeid(*pc).name(), typeid(*pa).name());
    D *back = dynamic_cast<D *>(pc);
    B *cross = dynamic_cast<B *>(pc);
    std::printf("%d %d\n", back == &x, cross == pb);
    std::printf("%d %d\n", (int) sizeof(D), (int) sizeof(C));
  }
  std::printf("%d %d\n", made, gone);
  A *h = new D(); delete h;
  std::printf("%d %d\n", made, gone);
  return 0;
}
