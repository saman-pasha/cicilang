// a nearly empty base whose virtual base lies outside it, the primary: `C : virtual I' over `I : virtual A', A with data
#include <cstdio>
#include <typeinfo>
struct A { int a = 1; virtual int fa() { return 10 + a; } virtual ~A() {} };
struct I : virtual A { virtual int f() { return 2; } int fa() override { return 20 + a; } };
struct C : virtual I { int c = 3; int f() override { return 30 + c; } virtual int k() { return 4; } };
struct D : C { int d = 5; int fa() override { return 50 + d; } };
struct E : virtual C { int e = 6; int k() override { return 60 + e; } };
static long off(const void *p, const void *q) { return (const char *) p - (const char *) q; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu %zu %zu\n", sizeof(A), sizeof(I), sizeof(C), sizeof(D), sizeof(E));
  C c; D d; E e;
  std::printf("C: I %ld A %ld c %ld f %d %d fa %d %d k %d\n", off((I *) &c, &c), off((A *) &c, &c), off(&c.c, &c), c.f(), ((I *) &c)->f(), ((A *) &c)->fa(), ((I *) &c)->fa(), c.k());
  std::printf("D: I %ld A %ld C %ld d %ld f %d fa %d %d\n", off((I *) &d, &d), off((A *) &d, &d), off((C *) &d, &d), off(&d.d, &d), ((I *) &d)->f(), ((A *) &d)->fa(), ((I *) &d)->fa());
  std::printf("E: I %ld A %ld C %ld e %ld f %d fa %d k %d %d\n", off((I *) &e, &e), off((A *) &e, &e), off((C *) &e, &e), off(&e.e, &e), ((I *) &e)->f(), ((A *) &e)->fa(), ((C *) &e)->k(), e.k());
  tab("C", &c, 6); tab("D", &d, 6); tab("E", &e, 7); tab("E.C", (C *) &e, 6);
  std::printf("%s %s %s %s\n", typeid(*(A *) &c).name(), typeid(*(I *) &d).name(), typeid(*(A *) &e).name(), typeid(*(C *) &e).name());
  std::printf("dc %d %d %d %d\n", dynamic_cast<C *>((A *) &c) == &c, dynamic_cast<D *>((I *) &d) == &d, dynamic_cast<E *>((A *) &e) == &e, dynamic_cast<I *>((A *) &e) == (I *) &e);
  A *p = new D; std::printf("new D %d\n", p->fa()); delete p; p = new E; std::printf("new E %d\n", p->fa()); delete p;
  C cc = c; D dc = d; E ec = e; std::printf("copies %d %d %d %d\n", cc.f(), ((A *) &dc)->fa(), ((C *) &ec)->k(), ((I *) &ec)->f());
  return 0;
}
