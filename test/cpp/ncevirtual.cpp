#include <cstdio>
struct A { virtual ~A() = default; virtual int f() const { return 1; } };
struct B { virtual ~B() = default; virtual int g() const { return 2; } };
struct D : A, B { int g() const override { return 20; } int f() const override { return 10; } };
constexpr int u() { D d; const B &rb = d; const A &ra = d; return rb.g() + ra.f(); }
static_assert(u() == 30);
int main() { std::printf("%d\n", u()); }
