// C++20'S CONSTANT EVALUATION OF VIRTUAL CALLS AND DYNAMIC_CAST (0.257; P1064, P1327): an overrider that reads the derived object's
// members, a base's function that calls a virtual one, a null dynamic_cast, three levels, delete through a base's pointer (the
// deleting destructor's slot), a call from a base's constructor (the base's table), a static_cast down -- each a static assertion
#include <cstdio>
struct B { int base = 10; constexpr virtual int f() const { return 1; } constexpr virtual int h() const { return 100 + f(); } constexpr virtual ~B() = default; };
struct D : B { int x = 7; constexpr int f() const override { return x + base; } };
struct D1 : B {}; struct D2 : B {};
struct A3 { constexpr virtual int f() const { return 1; } }; struct B3 : A3 { constexpr int f() const override { return 2; } }; struct C3 : B3 { constexpr int f() const override { return 3; } };
struct CB { int v; constexpr CB() : v(f()) {} constexpr virtual int f() const { return 1; } }; struct CD : CB { constexpr int f() const override { return 2; } };
constexpr int ovr() { D d; const B &b = d; return b.f(); }
constexpr int up() { D d; const B &b = d; return b.h(); }
constexpr int nul() { D1 d; B *b = &d; return dynamic_cast<D2 *>(b) == nullptr ? 1 : 0; }
constexpr int three() { C3 c; const A3 &a = c; return a.f(); }
constexpr int del() { B *p = new D; int r = p->f(); delete p; return r; }
constexpr int ctor() { CD d; return d.v * 10 + d.f(); }
constexpr int down() { D d; const B &b = d; const D &dd = static_cast<const D &>(b); return dd.x; }
int main() {
  static_assert(ovr() == 17); static_assert(up() == 117); static_assert(nul() == 1); static_assert(three() == 3);
  static_assert(del() == 17); static_assert(ctor() == 12); static_assert(down() == 7);
  std::printf("%d %d %d %d %d %d %d\n", ovr(), up(), nul(), three(), del(), ctor(), down());
}
