// the VTT (0.172): a path whose first base has a table of its own and whose later base holds the virtual base (0.171's
// shapes, a crash before): its constructor calls its new virtual function, an override of the base's and one of the vbase's
#include <cstdio>
struct PA { int a = 1; virtual int f() { return 10 + a; } virtual ~PA() {} };
struct PB { int b = 2; virtual int g() { return 20 + b; } virtual ~PB() {} };
struct X : virtual PA { int x = 3; };
struct P : PB, X {
    int p = 4;
    P() { std::printf("P:%d,%d,%d ", g(), f(), h()); }
    virtual int h() { return 70 + p; }
    int g() override { return 30 + p; }
    int f() override { return 40 + p; }
};
struct Q : virtual PA { int q = 5; };
struct D : P, Q { int d = 6; D() { std::printf("D:%d,%d,%d\n", g(), f(), h()); } int h() override { return 80 + d; } };
int main() {
    D d;
    PB *pb = &d; PA *pa = &d; P *pp = &d;
    std::printf("%zu %d %d %d\n", sizeof(D), pb->g(), pa->f(), pp->h());
    return 0;
}
