// a conditional class initializer: built in place by the arm taken; an lvalue arm beside a prvalue arm copied
#include <cstdio>
#include <string>
struct C {
  int v;
  C(int x) : v(x) { std::printf("C(%d)\n", v); }
  C(const C &o) : v(o.v + 100) { std::printf("copy %d\n", v); }
  ~C() { std::printf("~C(%d)\n", v); }
};
bool flip(int k) { return k % 2 == 0; }
int main() {
  C a = flip(2) ? C(1) : C(2);
  C b = flip(3) ? C(3) : C(4);
  C c = flip(4) ? a : C(5);
  C d = flip(5) ? a : C(6);
  const C &r = flip(6) ? a : b;
  std::printf("%d %d %d %d %d\n", a.v, b.v, c.v, d.v, r.v);
  std::string s = flip(1) ? std::string("odd") : std::string("even");
  std::string t = flip(2) ? s : std::string("other");
  std::printf("%s %s\n", s.c_str(), t.c_str());
  return 0;
}
