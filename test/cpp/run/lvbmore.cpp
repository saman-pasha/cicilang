// later virtual bases with virtual bases of their own, more shapes (0.173): a diamond D : X1, X2 over X1 : B1, virtual V and
// X2 : B2, virtual V (V : virtual A); S : B1, virtual V, virtual A; M : virtual A, B1, virtual V; dynamic_cast and typeid
#include <cstdio>
#include <typeinfo>
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
struct A { int a = 1; A() { std::printf("A "); } virtual int fa() { return 10 + a; } virtual ~A() {} };
struct V : virtual A { int v = 2; V() { std::printf("V "); } int fa() override { return 20 + v; } virtual int fv() { return 30 + v; } };
struct B1 { int b1 = 3; B1() { std::printf("B1 "); } };
struct B2 { int b2 = 4; B2() { std::printf("B2 "); } };
struct X1 : B1, virtual V { int x1 = 5; X1() { std::printf("X1(%d) ", fv()); } int fv() override { return 40 + x1; } };
struct X2 : B2, virtual V { int x2 = 6; X2() { std::printf("X2(%d %d) ", fv(), fa()); } int fa() override { return 60 + x2; } };
struct D : X1, X2 { int d = 7; D() { std::printf("D(%d %d) ", fv(), fa()); } };
struct S : B1, virtual V, virtual A { int s = 8; S() { std::printf("S(%d) ", fa()); } };
struct M : virtual A, B1, virtual V { int m = 9; M() { std::printf("M(%d %d) ", fa(), fv()); } int fv() override { return 90 + m; } };
int main() {
    { D d; std::printf("\n%zu %ld %ld %ld %ld %ld\n", sizeof(D), off(static_cast<X2 *>(&d), &d), off(static_cast<V *>(&d), &d), off(static_cast<A *>(&d), &d), off(&d.d, &d), off(&d.x2, &d));
      A *pa = &d; V *pv = &d; X1 *p1 = &d; X2 *p2 = &d;
      std::printf("%d %d %d %d %d\n", pa->fa(), pv->fv(), p1->fv(), p2->fa(), d.a + d.v);
      std::printf("%d %d %d %d\n", dynamic_cast<D *>(pa) == &d, dynamic_cast<X2 *>(pv) == p2, dynamic_cast<X1 *>(p2) == p1, typeid(*pa) == typeid(D)); }
    std::printf("\n");
    { S s; std::printf("\n%zu %ld %ld %ld\n", sizeof(S), off(static_cast<V *>(&s), &s), off(static_cast<A *>(&s), &s), off(&s.s, &s));
      A *pa = &s; std::printf("%d %d %d\n", pa->fa(), s.a, dynamic_cast<S *>(pa) == &s); }
    std::printf("\n");
    { M m; std::printf("\n%zu %ld %ld %ld %ld\n", sizeof(M), off(static_cast<B1 *>(&m), &m), off(static_cast<V *>(&m), &m), off(static_cast<A *>(&m), &m), off(&m.m, &m));
      A *pa = &m; V *pv = &m; std::printf("%d %d %d %d\n", pa->fa(), pv->fv(), m.a, dynamic_cast<M *>(pv) == &m);
      M m2 = m; std::printf("%d %d\n", m2.m, static_cast<V *>(&m2)->fv()); }
    std::printf("\n");
    return 0;
}
