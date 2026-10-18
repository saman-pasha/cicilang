// the virtual calls while each part is built and destroyed, the primary virtual base stolen from the part (construction tables)
#include <cstdio>
#include <typeinfo>
static int depth = 0;
struct I { virtual int f() { return 1; } virtual const char *who() { return "I"; } virtual ~I() { std::printf("~I %s %d\n", who(), f()); } };
struct X : virtual I {
  int x = 2;
  X() { std::printf("X() %s %d %s\n", ((I *) this)->who(), ((I *) this)->f(), typeid(*(I *) this).name()); }
  ~X() override { std::printf("~X %s %d %s\n", ((I *) this)->who(), ((I *) this)->f(), typeid(*(I *) this).name()); }
  int f() override { return 20 + x; } const char *who() override { return "X"; } virtual int k() { return 30 + x; }
};
struct D : virtual X {
  int d = 3;
  D() { std::printf("D() %s %d %d\n", ((I *) this)->who(), ((I *) this)->f(), ((X *) this)->k()); }
  ~D() override { std::printf("~D %s %d\n", ((I *) this)->who(), ((I *) this)->f()); }
  const char *who() override { return "D"; } int k() override { return 40 + d; }
};
struct D2 : virtual X, virtual I { int d2 = 4; D2() { std::printf("D2() %s %d\n", ((I *) this)->who(), ((X *) this)->k()); } int f() override { return 70 + d2; } };
struct F : D { int fv = 5; F() { std::printf("F() %s %d %d\n", ((I *) this)->who(), ((I *) this)->f(), ((X *) this)->k()); } const char *who() override { return "F"; } };
int main() {
  { D d; std::printf("in D: %s %d %d\n", ((I *) &d)->who(), ((I *) &d)->f(), ((X *) &d)->k()); }
  { D2 d2; std::printf("in D2: %s %d\n", ((I *) &d2)->who(), ((I *) &d2)->f()); }
  { F f; std::printf("in F: %s %d %d sizes %zu %zu %zu\n", ((I *) &f)->who(), ((I *) &f)->f(), ((X *) &f)->k(), sizeof(D), sizeof(D2), sizeof(F)); }
  I *p = new F; delete p;
  return 0;
}
