// the Itanium layout of a class over a virtual base through a single path (0.163): D : B and E : D over B : virtual V, and X :
// D, C, a diamond of a holder and a class over the base itself -- sizes, offsets, virtual calls and casts as clang lays them;
// and the virtual base built by the MOST DERIVED class ([class.base.init]/13), B's initializer of it ignored under D
#include <cstdio>
#include <cstddef>
struct V { int v = 1; virtual int f() { return v; } virtual ~V() {} };
struct B : virtual V { int b = 2; int f() override { return v + b; } };
struct D : B { int d = 3; int f() override { return v + b + d; } };
struct E : D { int e = 4; int f() override { return v + b + d + e; } };
struct C : virtual V { int c = 5; };
struct X : D, C { int x = 6; int f() override { return v + b + d + c + x; } };
struct VI { int v; VI(int k = 1) : v(k) {} };
struct BI : virtual VI { int b = 2; BI() : VI(5) {} };
struct DI : BI { int d = 3; };
struct DJ : BI { int d = 4; DJ() : VI(7) {} };
static long off(const void *o, const void *m) { return (const char *) m - (const char *) o; }
int main() {
  D d; E e; X x;
  printf("sizes %zu %zu %zu %zu %zu %zu\n", sizeof(V), sizeof(B), sizeof(D), sizeof(E), sizeof(C), sizeof(X));
  printf("D %ld %ld %ld\n", off(&d, &d.v), off(&d, &d.b), off(&d, &d.d));
  printf("E %ld %ld %ld %ld\n", off(&e, &e.v), off(&e, &e.b), off(&e, &e.d), off(&e, &e.e));
  printf("X %ld %ld %ld %ld %ld\n", off(&x, &x.v), off(&x, &x.b), off(&x, &x.d), off(&x, &x.c), off(&x, &x.x));
  V *pv = &e; B *pb = &e; D *pd = &e;
  printf("calls %d %d %d %d\n", pv->f(), pb->f(), pd->f(), e.f());
  V *qv = &x; C *qc = &x;
  printf("x %d %d %d\n", qv->f(), qc->f(), x.f());
  printf("cast %d %d %d\n", dynamic_cast<E *>(pv) == &e, dynamic_cast<X *>(qv) == &x, dynamic_cast<C *>(qv) == qc);
  BI bi; DI di; DJ dj;
  printf("init %d %d %d %d %d\n", bi.v, di.v, dj.v, di.b + di.d, dj.b + dj.d);
  return 0;
}
