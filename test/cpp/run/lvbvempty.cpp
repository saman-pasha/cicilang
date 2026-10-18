// a later virtual base over an EMPTY virtual base (0.173): X : B, virtual V over V : virtual E -- E at X's own address,
// built once before V, destroyed after it; and Y : X
#include <cstdio>
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
struct E { E() { std::printf("E "); } ~E() { std::printf("~E "); } };
struct V : virtual E { int v = 2; V() { std::printf("V "); } virtual int fv() { return 20 + v; } virtual ~V() { std::printf("~V "); } };
struct B { int b = 3; B() { std::printf("B "); } };
struct X : B, virtual V { int x = 4; X() { std::printf("X(%d) ", fv()); } int fv() override { return 40 + x; } };
struct Y : X { int y = 5; Y() { std::printf("Y(%d) ", fv()); } };
int main() {
    { X x; std::printf("\n%zu %ld %ld %ld %d %d\n", sizeof(X), off(static_cast<V *>(&x), &x), off(static_cast<E *>(&x), &x), off(&x.x, &x), static_cast<V *>(&x)->fv(), x.v); }
    std::printf("\n");
    { Y y; std::printf("\n%zu %ld %ld %ld %d\n", sizeof(Y), off(static_cast<V *>(&y), &y), off(static_cast<E *>(&y), &y), off(&y.y, &y), static_cast<V *>(&y)->fv());
      X x2 = y; std::printf("%d %d\n", x2.x, static_cast<V *>(&x2)->fv()); }
    std::printf("\n");
    return 0;
}
