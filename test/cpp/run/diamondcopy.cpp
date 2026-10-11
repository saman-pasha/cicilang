// The implicit copy and assignment of a diamond (0.135): the shared virtual base copied once, each path's members, the holder's own.
#include <cstdio>
#include <string>
struct A { virtual ~A() {} std::string s = "a0"; int n = 0; };
struct B : virtual A { int b = 0; };
struct C : virtual A { int c = 0; };
struct D : B, C { int d = 0; };
int main() {
  D d1; d1.s = "shared"; d1.n = 7; d1.b = 1; d1.c = 2; d1.d = 3;
  D d2 = d1;
  std::printf("%s %d %d %d %d\n", d2.s.c_str(), d2.n, d2.b, d2.c, d2.d);
  D d3; d3 = d1;
  std::printf("%s %d %d %d %d\n", d3.s.c_str(), d3.n, d3.b, d3.c, d3.d);
  A &ra = d2; std::printf("%s\n", ra.s.c_str());
  return 0;
}
