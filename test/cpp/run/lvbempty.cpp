// an EMPTY later virtual base (0.172): X : B, virtual E is dynamic, its table pointer first and E at its own address,
// as clang lays it; an empty one with a constructor and a destructor built and destroyed once; copies and a derived class
#include <cstdio>
struct E { };
struct F { F() { std::printf("F "); } F(const F &) { std::printf("Fc "); } ~F() { std::printf("~F "); } };
struct B { int b = 3; };
struct X : B, virtual E { int x = 4; };
struct Y : B, virtual F { int y = 5; };
struct XX : X { int xx = 6; };
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
int main() {
    X x; XX xx;
    std::printf("%d %zu %zu %ld %ld %ld\n", x.x, sizeof(X), sizeof(XX), off(static_cast<E *>(&x), &x), off(static_cast<B *>(&x), &x), off(&x.x, &x));
    X c = x; XX d = xx;
    std::printf("%d %d %d %ld\n", c.x, c.b, d.xx, off(static_cast<E *>(&d), &d));
    {
        Y y;
        std::printf("%d %zu ", y.y, sizeof(Y));
        Y z = y;
        std::printf("%d ", z.y);
    }
    std::printf("\n");
    return 0;
}
