// the type information of a pointer to a class -- the program's own, a polymorphic one, a library class with a table and one
// without, cv-qualified pointees, a plain struct -- and a pointer caught: an int's, a base's of a thrown derived pointer, one
// adjusted to a second base (0.179: a pointer handler read where the pointer points, a crash)
#include <cstdio>
#include <stdexcept>
#include <string>
#include <typeinfo>
struct A { int a; };
struct B { virtual ~B() {} int b; };
struct D : B { int d; };
struct P { int x; int y; };
struct E1 { int e1; };
struct E2 { int e2; };
struct F : E1, E2 { int f; };
int k = 42;
F fo;
int main() {
  A *pa = nullptr; const B *pb = nullptr; volatile D *pd = nullptr; const volatile P *pp = nullptr;
  std::printf("%s %s %s %s\n", typeid(pa).name(), typeid(pb).name(), typeid(pd).name(), typeid(pp).name());
  std::runtime_error *pr = nullptr; std::string *ps = nullptr;
  std::printf("%s %s\n", typeid(pr).name(), typeid(ps).name());
  std::printf("%d %d\n", typeid(A *) == typeid(pa), typeid(const B *) == typeid(B *));
  D d; d.b = 4; d.d = 5;
  try { throw &d; } catch (B *p) { std::printf("caught %d\n", p->b); }
  try { throw static_cast<const D *>(&d); } catch (const B *p) { std::printf("caught const %d\n", p->b); }
  try { throw &k; } catch (int *p) { std::printf("caught int %d\n", *p); }
  fo.e1 = 7; fo.e2 = 8; fo.f = 9;
  try { throw &fo; } catch (E2 *p) { std::printf("caught second base %d %d\n", p->e2, (int) ((char *) p - (char *) &fo)); }
  try { throw &fo; } catch (A *p) { std::printf("wrong\n"); } catch (F *p) { std::printf("caught F %d\n", p->f); }
  return 0;
}
