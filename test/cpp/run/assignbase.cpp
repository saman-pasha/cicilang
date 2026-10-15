// The implicit assignment (0.135): a class with a table assigns its members and keeps the object's table, through a base
// reference too; the memberwise assignment assigns the base sub-objects; a derived object copies its base sub-object.
#include <cstdio>
#include <string>
#include <utility>
struct B { virtual int f() { return 1; } int x = 0; };
struct D : B { int y = 0; int f() override { return 2; } };
struct SB { std::string s; };
struct SD : SB { std::string t; };
struct VB { virtual ~VB() {} std::string n; };
struct VD : VB { int k = 0; };
struct P { int a = 1; };
struct Q : P { int b = 2; };
int main() {
  D d; d.x = 10; d.y = 20;
  B &rb = d; B b2; b2.x = 77; rb = b2;
  std::printf("f=%d x=%d y=%d\n", rb.f(), d.x, d.y);
  B sliced = d; std::printf("sliced f=%d x=%d\n", sliced.f(), sliced.x);
  SD a, b; b.s = "base-part"; b.t = "own-part"; a = b;
  std::printf("%s %s\n", a.s.c_str(), a.t.c_str());
  SD c; c = std::move(b); std::printf("%s %s\n", c.s.c_str(), c.t.c_str());
  VD v1, v2; v2.n = "named"; v2.k = 3; v1 = v2; std::printf("%s %d\n", v1.n.c_str(), v1.k);
  Q q; q.a = 5; P p = q; std::printf("p.a=%d\n", p.a);
  return 0;
}
