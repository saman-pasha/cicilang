// a path that reaches an EMPTY virtual base further in, beside a later virtual base (0.173): X : P, virtual A over
// P : Q and Q : virtual E -- P kept whole, E built once, A at X's end
#include <cstdio>
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
struct E { E() { std::printf("E() "); } ~E() { std::printf("~E "); } };
struct Q : virtual E { int q = 1; virtual int fq() { return 10 + q; } };
struct P : Q { int p = 2; int fq() override { return 20 + p; } };
struct A { int a = 3; A() { std::printf("A() "); } ~A() { std::printf("~A "); } };
struct X : P, virtual A { int x = 4; };
int main() {
    { X x; std::printf("\n%zu %ld %ld %d %d %d %d %d\n", sizeof(X), off(static_cast<A *>(&x), &x), off(&x.x, &x), x.q, x.p, x.a, x.x, static_cast<Q *>(&x)->fq()); }
    std::printf("\n");
    return 0;
}
