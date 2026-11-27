// unevaluated operands that name a member with no object (1.6.31; [expr.prim.id.general]/4): sizeof, decltype and alignof
// of a member in a lambda that captured no this -- by itself, with its class, through this, a base's, in a static
// member function's lambda -- and sizeof(S::a) in main; they were `use of undeclared identifier', `decltype_unknown',
// `undeclared('S.a')' and the lowering's sizeof(arrow(id(this),a))
#include <cstdio>
struct B { short b; };
struct S : B {
  long a; char c[3];
  int f() {
    auto g = [] { return (int) sizeof(a); };
    auto h = [] { return (int) sizeof(c); };
    auto k = [] { decltype(a) z = 4; return (int) z; };
    auto n = [] { return (int) sizeof(S::a); };
    auto m = [] { return (int) sizeof(this->a); };
    auto o = [] { return (int) sizeof(b) + (int) sizeof(B::b); };
    auto q = [] { return (int) alignof(decltype(c)); };
    return g() * 1000000 + h() * 100000 + k() * 10000 + n() * 1000 + m() * 100 + o() * 10 + q();
  }
  static int s() { auto g = [] { return (int) sizeof(a) + (int) sizeof(S::c); }; return g(); }
};
int main() { S s{}; std::printf("%d %d %d\n", s.f(), S::s(), (int) sizeof(S::a)); return 0; }
