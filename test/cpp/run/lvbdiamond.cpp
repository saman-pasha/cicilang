// a diamond over a later virtual base (0.172): P holds A as its first base, Q as a later one, D holds A once through
// both paths; F : E, P over E : virtual A, virtual B
#include <cstdio>
struct A { int a = 1; };
struct B { int b = 2; };
struct P : virtual A { int p = 3; };
struct Q : B, virtual A { int q = 4; };
struct D : P, Q { int d = 5; };
struct E : virtual A, virtual B { int e = 6; };
struct F : E, P { int f = 7; };
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
int main() {
    D d;
    P *pp = &d;
    Q *pq = &d;
    A *pa = &d;
    std::printf("%zu %zu %zu %d %d %d %d %d\n", sizeof(P), sizeof(Q), sizeof(D), d.a, d.b, d.p, d.q, d.d);
    std::printf("%ld %ld %ld %ld\n", off(pp, &d), off(pq, &d), off(pa, &d), off(&d.d, &d));
    pp->a = 11;
    std::printf("%d %d %d\n", pq->a, pa->a, d.a);
    pq->a = 12;
    std::printf("%d %d\n", pp->a, d.a);
    D c = d;
    std::printf("%d %d %d\n", c.a, c.q, c.d);
    F f;
    E *pe = &f;
    std::printf("%zu %zu %d %d %d %d %d\n", sizeof(E), sizeof(F), f.a, f.b, f.e, f.p, f.f);
    std::printf("%ld %ld %ld %ld\n", off(pe, &f), off(static_cast<P *>(&f), &f), off(static_cast<A *>(&f), &f), off(static_cast<B *>(&f), &f));
    pe->a = 21;
    pe->b = 22;
    std::printf("%d %d %d\n", f.a, f.b, static_cast<P &>(f).a);
    return 0;
}
