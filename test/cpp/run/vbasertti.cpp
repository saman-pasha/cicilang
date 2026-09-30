// a polymorphic virtual base: this class's table in its sub-object, typeid and dynamic_cast through it (0.110)
#include <cstdio>
#include <typeinfo>
struct A { virtual ~A() {} virtual int f() { return 1; } int a = 10; };
struct B : virtual A { int f() override { return 2; } int b = 20; };
struct E : A { int e = 5; };
int main() {
  B b;
  A *pa = &b;
  printf("%d %s %d\n", pa->f(), typeid(*pa).name(), pa->a);
  B *pb = dynamic_cast<B *>(pa);
  E *pe = dynamic_cast<E *>(pa);
  printf("%d %d\n", pb ? pb->b : -1, pe ? pe->e : -1);
  printf("%d\n", typeid(b) == typeid(B));
  return 0;
}
