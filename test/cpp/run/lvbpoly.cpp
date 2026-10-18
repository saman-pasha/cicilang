// later POLYMORPHIC virtual bases (0.172): virtual calls through each base, overrides, dynamic_cast, a delete through
// a base, the order of the constructors and destructors, a copy and a class derived from one
#include <cstdio>
struct PA { int a = 1; PA() { std::printf("PA "); } virtual int fa() { return 10 + a; } virtual ~PA() { std::printf("~PA "); } };
struct PW { int w = 2; PW() { std::printf("PW "); } virtual int fw() { return 20 + w; } virtual ~PW() { std::printf("~PW "); } };
struct B { int b = 3; B() { std::printf("B "); } ~B() { std::printf("~B "); } };
struct X : virtual PA, virtual PW { int x = 4; X() { std::printf("X "); } int fw() override { return 40 + x; } ~X() { std::printf("~X "); } };
struct Y : B, virtual PA { int y = 5; Y() { std::printf("Y "); } int fa() override { return 50 + y; } ~Y() { std::printf("~Y "); } };
struct XX : X { int xx = 6; XX() { std::printf("XX "); } int fa() override { return 60 + xx; } };
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
int main() {
    {
        X x;
        std::printf("\n%zu %d %d %d %d\n", sizeof(X), x.a, x.w, x.x, x.fw());
        PA *pa = &x;
        PW *pw = &x;
        std::printf("%d %d %ld %ld\n", pa->fa(), pw->fw(), off(pa, &x), off(pw, &x));
        std::printf("%d %d %d\n", dynamic_cast<X *>(pw) == &x, dynamic_cast<PW *>(pa) == pw, dynamic_cast<X *>(pa) == &x);
        X c = x;
        std::printf("%d %d %d\n", c.a, c.w, static_cast<PW &>(c).fw());
    }
    std::printf("\n");
    {
        Y y;
        std::printf("\n%zu %d %d %d\n", sizeof(Y), y.a, y.b, y.y);
        PA *pa = &y;
        std::printf("%d %ld %d\n", pa->fa(), off(pa, &y), dynamic_cast<Y *>(pa) == &y);
    }
    std::printf("\n");
    {
        XX xx;
        std::printf("\n%zu %d %d %d %d\n", sizeof(XX), xx.a, xx.w, xx.x, xx.xx);
        PA *pa = &xx;
        PW *pw = &xx;
        X *px = &xx;
        std::printf("%d %d %d %d %ld %ld\n", pa->fa(), pw->fw(), px->fa(), px->fw(), off(pa, &xx), off(pw, &xx));
        std::printf("%d %d\n", dynamic_cast<XX *>(pw) == &xx, dynamic_cast<PA *>(pw) == pa);
    }
    std::printf("\n");
    PW *h = new X;
    std::printf("\n%d ", h->fw());
    delete h;
    std::printf("\n");
    return 0;
}
