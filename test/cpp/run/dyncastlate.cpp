// a dynamic_cast and a virtual call through a later base's table in a constant evaluation, and a pointer to a later base
// compared with the object's in the composite pointer type (0.258)
#include <cstdio>
struct A { virtual ~A() = default; constexpr virtual int f() const { return 1; } int a = 1; };
struct B { virtual ~B() = default; constexpr virtual int g() const { return 2; } int b = 2; };
struct D : A, B { constexpr int g() const override { return 20 + b; } constexpr int f() const override { return 10; } int d = 3; };
constexpr int t() { D d; B *pb = &d; D *pd = dynamic_cast<D *>(pb); A *pa = dynamic_cast<A *>(pb); return (pd == &d) + 2 * (pa == &d) + 4 * pd->b; }
static_assert(t() == 11);
constexpr int u() { D d; const B &rb = d; B *pb = &d; const A &ra = d; return rb.g() + ra.f() + pb->b + (static_cast<D *>(pb) == &d) + (pb == &d); }
static_assert(u() == 36);
int main() { D d; B *pb = &d; A *pa = &d; D *pd = &d; std::printf("%d %d %d %d %d %d %d\n", t(), u(), pb == &d, pa == &d, &d == pb, pb == pd, pb != pd); }
