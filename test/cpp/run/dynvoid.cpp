// dynamic_cast<void *> is the complete object, through the table's offset-to-top ([expr.dynamic.cast]/7; 0.112)
#include <cstdio>
struct A { int a = 1; virtual ~A() {} virtual int f() { return a; } };
struct B { int b = 2; virtual ~B() {} virtual int g() { return b; } };
struct C : A, B { int c = 3; int f() override { return c; } };
int main() {
  C obj;
  A *pa = &obj;
  B *pb = &obj;
  void *va = dynamic_cast<void *>(pa);
  void *vb = dynamic_cast<void *>(pb);
  std::printf("%d %d %d\n", (int) (va == (void *) &obj), (int) (vb == (void *) &obj), (int) ((char *) pb != (char *) pa));
  A *none = nullptr;
  std::printf("%d %d\n", (int) (dynamic_cast<void *>(none) == nullptr), pb->g() + pa->f());
  return 0;
}
