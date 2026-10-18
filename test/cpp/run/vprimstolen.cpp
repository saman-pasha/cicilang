// a class whose only dynamic bases are virtual steals a virtual base's nearly empty primary (clang's indirect primary base)
#include <cstdio>
#include <typeinfo>
struct I { virtual int f() { return 1; } virtual ~I() {} };
struct X : virtual I { int x = 2; int f() override { return 20 + x; } virtual int k() { return 3; } };
struct D : virtual X { int d = 3; };
struct D2 : virtual X, virtual I { int d2 = 4; int k() override { return 40 + d2; } };
struct E : virtual X { int e = 5; int f() override { return 50 + e; } };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu %zu\n", sizeof(X), sizeof(D), sizeof(D2), sizeof(E));
  D d; D2 d2; E e;
  std::printf("D: I %ld X %ld d %ld f %d %d %d k %d\n", off((I *) &d, &d), off((X *) &d, &d), off(&d.d, &d), d.f(), ((I *) &d)->f(), ((X *) &d)->f(), ((X *) &d)->k());
  std::printf("D2: I %ld X %ld d2 %ld f %d k %d %d\n", off((I *) &d2, &d2), off((X *) &d2, &d2), off(&d2.d2, &d2), ((I *) &d2)->f(), ((X *) &d2)->k(), d2.k());
  std::printf("E: I %ld X %ld e %ld f %d %d k %d\n", off((I *) &e, &e), off((X *) &e, &e), off(&e.e, &e), ((I *) &e)->f(), ((X *) &e)->f(), ((X *) &e)->k());
  tab("D", &d, 6); tab("D.X", (X *) &d, 6); tab("E", &e, 6); tab("E.X", (X *) &e, 6);
  std::printf("%s %s %s\n", typeid(*(I *) &d).name(), typeid(*(X *) &d2).name(), typeid(*(I *) &e).name());
  std::printf("dc %d %d %d\n", dynamic_cast<D *>((I *) &d) == &d, dynamic_cast<D2 *>((X *) &d2) == &d2, dynamic_cast<X *>((I *) &e) == (X *) &e);
  I *p = new D; std::printf("new D %d\n", p->f()); delete p; p = new E; std::printf("new E %d\n", p->f()); delete p;
  D dc = d; E ec = e; std::printf("copies %d %d\n", dc.f(), ec.f());
  return 0;
}
