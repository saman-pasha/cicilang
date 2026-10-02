// a second base's virtual overridden two classes down: the derived class's own secondary tables (0.110)
#include <cstdio>
struct A { virtual ~A() {} virtual int f() { return 1; } int a = 1; };
struct B { virtual ~B() {} virtual int g() { return 10; } virtual int h() { return 100; } int b = 2; };
struct C : A, B { int g() override { return 20 + b; } int c = 3; };
struct D : C { int g() override { return 30 + c; } int h() override { return 300 + a; } int d = 4; };
struct E : D { int f() override { return 5; } };
int main() {
  D d; E e;
  B *pb = &d; B *pe = &e; A *pa = &e;
  printf("%d %d %d %d %d\n", pb->g(), pb->h(), pe->g(), pe->h(), pa->f());
  C *pc = &d;
  printf("%d %d\n", pc->g(), static_cast<B *>(pc)->h());
  B *heap = new E;
  printf("%d\n", heap->g());
  delete heap;
  return 0;
}
