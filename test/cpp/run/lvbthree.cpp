// three virtual bases in one class written in an order of their own (0.172), a class derived from it, and a class that
// names one of them as its virtual first base before it (TU : virtual U, T): offsets, members, copies
#include <cstdio>
struct A { int a = 1; };
struct W { int w = 2; };
struct U { int u = 3; };
struct T : virtual W, virtual A, virtual U { int t = 4; };
struct TT : T { int tt = 5; };
struct TU : virtual U, T { int tu = 6; };
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
int main() {
    T t; TT tt; TU tu;
    std::printf("%zu %zu %zu\n", sizeof(T), sizeof(TT), sizeof(TU));
    std::printf("%ld %ld %ld %ld | %ld %ld %ld %ld | %ld %ld %ld %ld %ld\n", off(static_cast<A *>(&t), &t), off(static_cast<W *>(&t), &t),
                off(static_cast<U *>(&t), &t), off(&t.t, &t), off(static_cast<A *>(&tt), &tt), off(static_cast<W *>(&tt), &tt),
                off(static_cast<U *>(&tt), &tt), off(&tt.tt, &tt), off(static_cast<A *>(&tu), &tu), off(static_cast<W *>(&tu), &tu),
                off(static_cast<U *>(&tu), &tu), off(static_cast<T *>(&tu), &tu), off(&tu.tu, &tu));
    T *pt = &tt;
    pt->a = 11; pt->w = 12; pt->u = 13;
    std::printf("%d %d %d %d %d\n", tt.a, tt.w, tt.u, tt.t, tt.tt);
    T *pu = &tu;
    pu->u = 23; pu->a = 21;
    std::printf("%d %d %d %d\n", tu.u, tu.a, tu.w, tu.tu);
    TT c = tt; TU d = tu;
    std::printf("%d %d %d %d %d\n", c.a, c.u, d.u, d.a, d.tu);
    return 0;
}
