// a later polymorphic base that adds virtual functions to its own primary base's (0.172): D : X, P over P : PB, its
// secondary table typed by P's own slots (refused since 0.108, the table one slot short)
#include <cstdio>
struct PB { int b = 1; virtual int g() { return 10 + b; } virtual ~PB() {} };
struct P : PB { int p = 2; virtual int h() { return 20 + p; } int g() override { return 30 + p; } };
struct X { int x = 3; virtual int k() { return 40 + x; } virtual ~X() {} };
struct D : X, P { int d = 4; int h() override { return 50 + d; } };
int main() {
    D d;
    P *pp = &d; PB *pb = &d; X *px = &d;
    std::printf("%zu %d %d %d %d\n", sizeof(D), pp->h(), pp->g(), pb->g(), px->k());
    return 0;
}
