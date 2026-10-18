// a virtual first base and a later virtual base that share a virtual base (0.173): X : virtual V, virtual W over
// V : virtual A and W : virtual A; Y : virtual V, virtual A; and Z : virtual V, W with W a path
#include <cstdio>
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
struct A { int a = 1; A() { std::printf("A "); } virtual int fa() { return 10 + a; } virtual ~A() { std::printf("~A "); } };
struct V : virtual A { int v = 2; V() { std::printf("V "); } int fa() override { return 20 + v; } ~V() { std::printf("~V "); } };
struct W : virtual A { int w = 3; W() { std::printf("W(%d) ", fw()); } virtual int fw() { return 30 + w + a; } ~W() { std::printf("~W "); } };
struct X : virtual V, virtual W { int x = 4; X() { std::printf("X(%d %d) ", fa(), fw()); } int fw() override { return 40 + x; } };
struct Y : virtual V, virtual A { int y = 5; Y() { std::printf("Y(%d) ", fa()); } };
struct Z : virtual V, W { int z = 6; Z() { std::printf("Z(%d %d) ", fa(), fw()); } int fw() override { return 60 + z + a; } };
int main() {
    { X x; std::printf("\n%zu %ld %ld %ld %ld\n", sizeof(X), off(static_cast<V *>(&x), &x), off(static_cast<A *>(&x), &x), off(static_cast<W *>(&x), &x), off(&x.x, &x));
      A *pa = &x; W *pw = &x; V *pv = &x; std::printf("%d %d %d %d %d\n", pa->fa(), pw->fw(), pw->a, pv->a, x.a + x.v + x.w);
      X x2 = x; std::printf("%d %d\n", static_cast<W *>(&x2)->fw(), static_cast<A *>(&x2)->fa()); }
    std::printf("\n");
    { Y y; std::printf("\n%zu %ld %ld %ld\n", sizeof(Y), off(static_cast<V *>(&y), &y), off(static_cast<A *>(&y), &y), off(&y.y, &y));
      A *pa = &y; std::printf("%d %d\n", pa->fa(), y.a); }
    std::printf("\n");
    { Z z; std::printf("\n%zu %ld %ld %ld %ld\n", sizeof(Z), off(static_cast<V *>(&z), &z), off(static_cast<A *>(&z), &z), off(static_cast<W *>(&z), &z), off(&z.z, &z));
      A *pa = &z; W *pw = &z; std::printf("%d %d %d %d\n", pa->fa(), pw->fw(), pw->a, z.a + z.v + z.w + z.z);
      Z z2 = z; std::printf("%d %d\n", static_cast<W *>(&z2)->fw(), z2.z); }
    std::printf("\n");
    return 0;
}
