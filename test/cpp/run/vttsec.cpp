// the VTT's secondary pointers (0.172): X : R, N over N : virtual A as a path of D and of a diamond F -- a virtual call
// through N, a later base that holds the virtual base, in X's constructor and destructor reaches X's override, through A too
#include <cstdio>
struct A { int a = 1; virtual int va() { return 10 + a; } virtual ~A() {} };
struct N : virtual A { int n = 2; virtual int h() { return 100 + n; } int va() override { return 30 + n; } };
struct R { int r = 3; virtual int g() { return 7 + r; } virtual ~R() {} };
struct X : R, N {
    int x = 4;
    int h() override { return 200 + x; }
    int va() override { return 40 + x; }
    X() { std::printf("X() %d %d %d\n", static_cast<N *>(this)->h(), static_cast<A *>(this)->va(), g()); }
    ~X() { std::printf("~X() %d %d\n", static_cast<N *>(this)->h(), static_cast<A *>(this)->va()); }
};
struct D : X {
    int d = 5;
    int h() override { return 500 + d; }
    D() { std::printf("D() %d\n", static_cast<N *>(this)->h()); }
    ~D() { std::printf("~D() %d\n", static_cast<N *>(this)->h()); }
};
struct E : virtual A { int e = 6; };
struct F : E, X { int f = 7; int va() override { return 70 + f; } };
int main() {
    { X x; std::printf("%d %d\n", static_cast<N *>(&x)->h(), static_cast<A *>(&x)->va()); }
    { D d; N *p = &d; A *q = &d; std::printf("%d %d %d\n", p->h(), q->va(), static_cast<R *>(&d)->g()); }
    { F f; std::printf("%d %d %d\n", static_cast<N *>(&f)->h(), static_cast<A *>(&f)->va(), (int) (sizeof(F) > sizeof(X))); }
    return 0;
}
