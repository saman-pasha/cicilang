// static member functions called bare in a lambda that captured nothing (1.6.33; [class.static.mfct]/2): the
// enclosing class's own, a base's -- which was `use of undeclared identifier' --, one with an argument from a static
// member function's lambda, a class template's, and a base's beside a derived one's of another name
#include <cstdio>
struct B { static int bs() { return 4; } static int twice(int k) { return 2 * k; } };
struct S { static int sm() { return 3; } int f() { auto g = [] { return sm(); }; return g(); } };
struct D : B { int f() { auto g = [] { return bs() + twice(5); }; return g(); } static int ds() { return 7; } int h() { auto g = [] { return ds() + bs(); }; return g(); } };
struct T { static int sm(int k) { return k; } static int sm2() { auto g = [] { return sm(5); }; return g(); } };
template <class X> struct U { static X sm() { return X(6); } X f() { auto g = [] { return sm(); }; return g(); } };
struct E : D { int f() { auto g = [] { return bs() * ds(); }; return g(); } };
int main() {
    S s; D d; U<int> u; E e;
    std::printf("%d %d %d %d %d %d\n", s.f(), d.f(), d.h(), T::sm2(), u.f(), e.f());
    return 0;
}
