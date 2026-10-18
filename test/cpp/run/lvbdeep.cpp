// a later virtual base over a class whose virtual FIRST base has a virtual base of its own (0.173): X : B, virtual W over
// W : virtual V and V : virtual A; and D : W, Z as a path
#include <cstdio>
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
struct A { int a = 1; A() { std::printf("A "); } virtual int fa() { return 10 + a; } virtual ~A() { std::printf("~A "); } };
struct V : virtual A { int v = 2; V() { std::printf("V "); } int fa() override { return 20 + v; } virtual int fv() { return 30 + v; } ~V() { std::printf("~V "); } };
struct W : virtual V { int w = 3; W() { std::printf("W(%d %d) ", fv(), fa()); } int fv() override { return 40 + w; } ~W() { std::printf("~W "); } };
struct B { int b = 4; B() { std::printf("B "); } ~B() { std::printf("~B "); } };
struct X : B, virtual W { int x = 5; X() { std::printf("X(%d %d) ", fv(), fa()); } int fa() override { return 50 + x; } ~X() { std::printf("~X "); } };
struct Z { int z = 6; virtual int fz() { return 60 + z; } virtual ~Z() {} };
struct D : W, Z { int d = 7; D() { std::printf("D(%d %d %d) ", fv(), fa(), fz()); } int fz() override { return 70 + d; } };
int main() {
    { X x; std::printf("\n%zu %ld %ld %ld %ld %ld\n", sizeof(X), off(static_cast<B *>(&x), &x), off(static_cast<W *>(&x), &x), off(static_cast<V *>(&x), &x), off(static_cast<A *>(&x), &x), off(&x.x, &x));
      W *pw = &x; V *pv = &x; A *pa = &x; std::printf("%d %d %d %d %d %d\n", pw->fv(), pw->fa(), pv->fv(), pa->fa(), pw->a, x.v); }
    std::printf("\n");
    { D d; std::printf("\n%zu %ld %ld %ld %ld %ld\n", sizeof(D), off(static_cast<Z *>(&d), &d), off(static_cast<V *>(&d), &d), off(static_cast<A *>(&d), &d), off(&d.d, &d), off(&d.w, &d));
      Z *pz = &d; V *pv = &d; A *pa = &d; std::printf("%d %d %d %d\n", pz->fz(), pv->fv(), pa->fa(), d.a + d.v + d.w + d.z + d.d);
      D d2 = d; std::printf("%d %d %d\n", d2.a, d2.v, static_cast<A *>(&d2)->fa()); }
    std::printf("\n");
    return 0;
}
