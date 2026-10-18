// a later virtual base with a virtual base of its own (0.173): X : B, virtual V over V : virtual A -- X holds V
// (its base-variant part) and A at its end, A built before V; a class derived from X, a copy
#include <cstdio>
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
struct A { int a = 1; A() { std::printf("A() "); } virtual int fa() { return 10 + a; } virtual ~A() { std::printf("~A "); } };
struct V : virtual A { int v = 2; V() { std::printf("V(%d) ", a); } int fa() override { return 20 + v; } virtual int fv() { return 30 + v; } ~V() { std::printf("~V "); } };
struct B { int b = 3; B() { std::printf("B() "); } ~B() { std::printf("~B "); } };
struct X : B, virtual V { int x = 4; X() { std::printf("X(%d %d) ", fv(), fa()); } int fv() override { return 40 + x; } ~X() { std::printf("~X "); } };
struct Y : X { int y = 5; int fa() override { return 50 + y; } };
int main() {
    { X x; std::printf("\n%zu %ld %ld %ld %ld\n", sizeof(X), off(static_cast<B *>(&x), &x), off(static_cast<V *>(&x), &x), off(static_cast<A *>(&x), &x), off(&x.x, &x));
      V *pv = &x; A *pa = &x; std::printf("%d %d %d %d %d\n", pv->fv(), pv->fa(), pa->fa(), pv->a, x.a); }
    std::printf("\n");
    { Y y; std::printf("\n%zu %ld %ld %ld\n", sizeof(Y), off(static_cast<V *>(&y), &y), off(static_cast<A *>(&y), &y), off(&y.y, &y));
      V *pv = &y; A *pa = &y; std::printf("%d %d %d\n", pv->fv(), pv->fa(), pa->fa());
      X x2 = y; std::printf("%d %d %d %d\n", x2.x, x2.v, x2.a, static_cast<A *>(&x2)->fa()); }
    std::printf("\n");
    return 0;
}
