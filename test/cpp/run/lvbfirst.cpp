// a virtual FIRST base with a virtual base of its own beside a later virtual base (0.173): X : virtual V, virtual W
// over V : virtual A, and X2 : virtual W, virtual V -- sizes, offsets, calls, a copy
#include <cstdio>
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
struct A { int a = 1; virtual int fa() { return 10 + a; } virtual ~A() {} };
struct V : virtual A { int v = 2; int fa() override { return 20 + v; } };
struct W { int w = 3; virtual int fw() { return 30 + w; } virtual ~W() {} };
struct X : virtual V, virtual W { int x = 4; int fw() override { return 40 + x; } };
struct X2 : virtual W, virtual V { int x2 = 5; int fa() override { return 60 + x2; } };
int main() {
    X x; X2 y;
    std::printf("%zu %ld %ld %ld %ld\n", sizeof(X), off(static_cast<V *>(&x), &x), off(static_cast<A *>(&x), &x), off(static_cast<W *>(&x), &x), off(&x.x, &x));
    std::printf("%zu %ld %ld %ld %ld\n", sizeof(X2), off(static_cast<V *>(&y), &y), off(static_cast<A *>(&y), &y), off(static_cast<W *>(&y), &y), off(&y.x2, &y));
    A *pa = &x; W *pw = &x; A *qa = &y; W *qw = &y;
    std::printf("%d %d %d %d %d %d\n", pa->fa(), pw->fw(), qa->fa(), qw->fw(), x.a + x.v + x.w, y.a + y.v + y.w);
    X x3 = x; std::printf("%d %d %d\n", x3.a, static_cast<A *>(&x3)->fa(), static_cast<W *>(&x3)->fw());
    return 0;
}
