// a virtual first base beside a later primary one (0.172): X : virtual A, R1 over R1 : virtual W shares R1's table
// pointer, A a later virtual base, both virtual bases at its end, as clang lays them
#include <cstdio>
struct A { int a = 1; };
struct W { int w = 2; };
struct R1 : virtual W { int r1 = 4; };
struct X : virtual A, R1 { int x = 5; };
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
int main() {
    X x;
    R1 *r = &x;
    A *pa = &x;
    W *pw = &x;
    std::printf("%zu %d %d %d %d\n", sizeof(X), x.a, x.w, x.r1, x.x);
    std::printf("%ld %ld %ld %ld\n", off(r, &x), off(pa, &x), off(pw, &x), off(&x.x, &x));
    r->w = 12;
    pa->a = 11;
    std::printf("%d %d %d %d\n", x.a, x.w, pa->a, pw->w);
    return 0;
}
