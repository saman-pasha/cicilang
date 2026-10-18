// a virtual destructor written `= default': the class has a table, and a delete through the base runs the derived destructor
#include <cstdio>
#include <string>
struct B { virtual ~B() = default; int b = 1; };
struct D : B { std::string s = "derived"; ~D() override { std::printf("~D %s\n", s.c_str()); } };
struct E : B { ~E() override = default; int e = 2; };
struct F : E { ~F() { std::printf("~F\n"); } };
int main() {
  std::printf("sizes %zu %zu %zu\n", sizeof(B), sizeof(D), sizeof(E));
  B *p = new D; delete p;
  B *q = new F; delete q;
  E *r = new F; delete r;
  return 0;
}
