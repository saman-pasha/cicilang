// classes over two virtual bases through their paths (0.171): `H1 : Q1, R1' holds A through Q1 and W through R1, each path
// its `.nv' form and both virtual bases at its end, as the Itanium ABI lays them; `D : H1, H2' is a diamond over the two
#include <cstdio>
struct A { int a = 1; };
struct W { int w = 2; };
struct Q1 : virtual A { int q1 = 3; };
struct R1 : virtual W { int r1 = 4; };
struct Q2 : virtual A { int q2 = 5; };
struct R2 : virtual W { int r2 = 6; };
struct H1 : Q1, R1 { int h1 = 7; };
struct H2 : Q2, R2 { int h2 = 8; };
struct D : H1, H2 { int d = 9; };
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
int main() {
    H1 h;
    Q1 *q = &h;
    R1 *r = &h;
    A *pa = &h;
    W *pw = &h;
    std::printf("%zu %d %d %d %d %d\n", sizeof(H1), h.a, h.w, h.q1, h.r1, h.h1);
    std::printf("%d %d %d %d\n", q->a, r->w, pa->a, pw->w);
    std::printf("%ld %ld %ld %ld %ld\n", off(q, &h), off(r, &h), off(pa, &h), off(pw, &h), off(&h.h1, &h));
    q->a = 11;
    r->w = 12;
    std::printf("%d %d %d %d\n", h.a, h.w, pa->a, pw->w);
    H1 g = h;
    std::printf("%d %d %d\n", g.a, g.w, g.h1);
    D d;
    H1 *h1 = &d;
    H2 *h2 = &d;
    Q2 *q2 = &d;
    R2 *r2 = &d;
    A *da = &d;
    W *dw = &d;
    std::printf("%zu %zu %zu\n", sizeof(D), sizeof(H1), sizeof(H2));
    std::printf("%d %d %d %d %d\n", d.a, d.w, d.h1, d.h2, d.d);
    std::printf("%ld %ld %ld %ld %ld %ld %ld\n", off(h1, &d), off(h2, &d), off(q2, &d), off(r2, &d), off(da, &d), off(dw, &d), off(&d.d, &d));
    h1->a = 21;
    h2->w = 22;
    q2->a += 1;
    r2->w += 1;
    std::printf("%d %d %d %d %d %d\n", d.a, d.w, da->a, dw->w, h2->a, h1->w);
    D e = d;
    std::printf("%d %d %d\n", e.a, e.w, e.d);
    return d.a + d.w + d.h1 + d.h2 - 60;
}
