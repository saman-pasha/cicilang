// two POLYMORPHIC virtual bases through their paths (0.171): virtual calls through each base, an override in a path and
// in the complete class, casts across, a delete through a base and the order of the destructors; and a diamond over the
// two whose second virtual base's function only the second path overrides -- its final overrider in every table, and in
// each path's constructor the path's own (a construction table for each held base)
#include <cstdio>
struct PA { int a = 1; virtual int fa() { return 10 + a; } virtual ~PA() { std::printf("~PA "); } };
struct PW { int w = 2; virtual int fw() { return 20 + w; } virtual ~PW() { std::printf("~PW "); } };
struct PQ : virtual PA { int q = 3; int fa() override { return 30 + q; } };
struct PR : virtual PW { int r = 4; };
struct PH : PQ, PR { int h = 7; int fw() override { return 70 + h; } ~PH() { std::printf("~PH "); } };
struct A { int a = 1; virtual int fa() { return 10 + a; } virtual ~A() {} };
struct W { int w = 2; virtual int fw() { return 20 + w; } virtual ~W() {} };
struct Q1 : virtual A { int q1 = 3; Q1() { std::printf("Q1:%d ", fa()); } int fa() override { return 30 + q1; } };
struct R1 : virtual W { int r1 = 4; R1() { std::printf("R1:%d ", fw()); } };
struct Q2 : virtual A { int q2 = 5; };
struct R2 : virtual W { int r2 = 6; R2() { std::printf("R2:%d ", fw()); } int fw() override { return 60 + r2; } };
struct H1 : Q1, R1 { int h1 = 7; H1() { std::printf("H1:%d,%d ", fa(), fw()); } };
struct H2 : Q2, R2 { int h2 = 8; };
struct D : H1, H2 { int d = 9; int fa() override { return 90 + d; } };
int main() {
    {
        PH h;
        PA *pa = &h;
        PW *pw = &h;
        PQ *q = &h;
        PR *r = &h;
        std::printf("%d %d %d %d %zu\n", pa->fa(), pw->fw(), q->fa(), r->fw(), sizeof(PH));
        std::printf("%d %d %d\n", dynamic_cast<PH *>(pw) == &h, dynamic_cast<PQ *>(pw) == q, dynamic_cast<PW *>(pa) == pw);
        PA *heap = new PH;
        std::printf("%d ", heap->fa());
        delete heap;
        std::printf("\n");
    }
    std::printf("\n");
    D d;
    std::printf("\n");
    A *pa = &d;
    W *pw = &d;
    H2 *h2 = &d;
    R1 *r1 = &d;
    std::printf("%d %d %d %d %zu\n", pa->fa(), pw->fw(), h2->fa(), r1->fw(), sizeof(D));
    std::printf("%d %d\n", dynamic_cast<D *>(pw) == &d, dynamic_cast<H2 *>(pa) == h2);
    D e = d;
    std::printf("%d %d %d\n", e.fa(), static_cast<W &>(e).fw(), e.a + e.w);
    return 0;
}
