// a primary virtual base further in that no base takes: `D : virtual X' over `X : P, virtual I' (X's primary is P, not I)
#include <cstdio>
#include <typeinfo>
struct P { virtual int p() { return 5; } int pd = 6; };
struct I { virtual int f() { return 1; } virtual ~I() {} };
struct X : P, virtual I { int x = 2; int f() override { return 20 + x; } int p() override { return 50 + pd; } };
struct D : virtual X { int d = 3; virtual int g() { return 7 + d; } };
struct E : virtual X { int e = 4; int f() override { return 60 + e; } };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu\n", sizeof(X), sizeof(D), sizeof(E));
  D d; E e;
  std::printf("D: I %ld X %ld P %ld d %ld f %d %d p %d g %d\n", off((I *) &d, &d), off((X *) &d, &d), off((P *) &d, &d), off(&d.d, &d), ((I *) &d)->f(), d.f(), ((P *) &d)->p(), d.g());
  std::printf("E: I %ld X %ld e %ld f %d %d p %d\n", off((I *) &e, &e), off((X *) &e, &e), off(&e.e, &e), ((I *) &e)->f(), ((X *) &e)->f(), ((P *) &e)->p());
  tab("D", &d, 6); tab("D.X", (X *) &d, 5); tab("E", &e, 6); tab("E.X", (X *) &e, 5);
  std::printf("%s %s %s %s\n", typeid(*(I *) &d).name(), typeid(*(P *) &d).name(), typeid(*(I *) &e).name(), typeid(*(X *) &e).name());
  std::printf("dc %d %d %d %d\n", dynamic_cast<D *>((I *) &d) == &d, dynamic_cast<X *>((I *) &d) == (X *) &d, dynamic_cast<E *>((P *) &e) == &e, dynamic_cast<P *>((I *) &e) == (P *) &e);
  I *q = new D; std::printf("new D %d\n", q->f()); delete q; q = new E; std::printf("new E %d\n", q->f()); delete q;
  D dc = d; E ec = e; std::printf("copies %d %d %d\n", dc.f(), ec.f(), ((I *) &ec)->f());
  return 0;
}
