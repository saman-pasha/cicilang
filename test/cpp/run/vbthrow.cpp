#include <cstdio>
#include <string>
// a constructor that throws destroys what it built: a virtual base the complete object built ([except.ctor]/3), and a
// delegating constructor's object its target completed ([except.ctor]/4)
static int live = 0;
struct V { std::string s; V() : s("a virtual base's string, long enough for a block") { ++live; } ~V() { --live; std::printf("~V\n"); } };
struct W { W() { ++live; } ~W() { --live; std::printf("~W\n"); } };
static int boom(int k) { if (k > 0) throw k; return k; }
struct P : virtual V { int p = 1; };
struct Q : virtual V, virtual W { int q; Q() : q(boom(2)) {} };
struct D : P { int d; D() : d(boom(3)) {} };
struct R : virtual V { int r; R() : r(boom(5)) {} };
struct E {
  std::string s;
  E() : s("a delegated object's string, long enough for a block") { ++live; }
  E(int k) : E() { if (k > 0) throw k; }
  ~E() { --live; std::printf("~E\n"); }
};
int main() {
  try { Q q; } catch (int e) { std::printf("Q threw %d, live %d\n", e, live); }
  try { D d; } catch (int e) { std::printf("D threw %d, live %d\n", e, live); }
  try { R r; } catch (int e) { std::printf("R threw %d, live %d\n", e, live); }
  try { E e(4); } catch (int e) { std::printf("E threw %d, live %d\n", e, live); }
  { E ok(0); std::printf("ok %d\n", live); }
  return 0;
}
