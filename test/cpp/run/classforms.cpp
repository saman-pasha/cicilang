// A data member's default initializer of class type; an out-of-class definition of a plain struct's static array
// member; the address of an overloaded member, chosen by the pointer it initializes
#include <cstdio>
#include <string>
struct Rec {
  std::string name = "anon";
  int n = 3;
  std::string tag{"t"};
};
struct Holder { static const bool flags[3]; int x; };
const bool Holder::flags[3] = {true, false, true};
struct Calc {
  int base;
  int add(int k) { return base + k; }
  int add(int a, int b) { return base + a + b; }
  double add(double d) { return base + d * 2; }
};
int main() {
  Rec r;
  Rec q;
  q.name += "!";
  std::printf("%s %d %s %s\n", r.name.c_str(), r.n, r.tag.c_str(), q.name.c_str());
  std::printf("%d %d %d\n", (int) Holder::flags[0], (int) Holder::flags[1], (int) Holder::flags[2]);
  Calc c{10};
  int (Calc::*p1)(int) = &Calc::add;
  int (Calc::*p2)(int, int) = &Calc::add;
  double (Calc::*p3)(double) = &Calc::add;
  std::printf("%d %d %g\n", (c.*p1)(1), (c.*p2)(1, 2), (c.*p3)(1.5));
  return 0;
}
