// the VTT (0.172): a diamond's path whose first base has a table of its own, P : PB, virtual PA -- the path's
// constructor and destructor run under its own construction tables after that base is built, its overrides called
#include <cstdio>
struct PA { int a = 1; virtual int f() { return 10 + a; } virtual ~PA() {} };
struct PB { int b = 2; virtual int g() { return 20 + b; } virtual ~PB() {} };
struct P : PB, virtual PA {
    int p = 3;
    P() { std::printf("P:%d,%d ", g(), f()); }
    ~P() { std::printf("~P:%d,%d ", g(), f()); }
    int g() override { return 30 + p; }
    int f() override { return 40 + p; }
};
struct Q : virtual PA { int q = 4; Q() { std::printf("Q:%d ", f()); } ~Q() { std::printf("~Q:%d ", f()); } };
struct D : P, Q {
    int d = 5;
    D() { std::printf("D:%d,%d ", g(), f()); }
    ~D() { std::printf("~D:%d,%d ", g(), f()); }
    int g() override { return 50 + d; }
    int f() override { return 60 + d; }
};
int main() {
    { D d; std::printf("\n%zu %d %d\n", sizeof(D), static_cast<PB &>(d).g(), static_cast<PA &>(d).f()); }
    std::printf("\n");
    return 0;
}
