// DEFINITIONS BY QUALIFIED NAMES (0.166; [namespace.memdef]/2, [class.mfct]/2): a namespace's function and variable, a
// namespaced class's members, constructor, destructor, static data member and operator, a nested class's member and
// constructor, and a class template's member defined outside their namespaces and classes
#include <cstdio>
namespace n {
int f();
extern int g;
int h(int);
namespace in { int k(); }
struct C { int v; static int count; C(); ~C(); int m() const; static int s(); bool operator==(const C &) const; };
template <class T> struct B { T t; T get() const; static T make(T); };
struct O2 { struct I2 { int w; I2(); int g() const; }; };
}
struct Outer { struct Inner { int w = 6; int f(); }; };
int n::f() { return 1; }
int n::g = 5;
int n::h(int x) { return x + g; }
int n::in::k() { return f() + 10; }
int n::C::count = 3;
n::C::C() : v(4) { count++; }
n::C::~C() { std::printf("~C %d\n", v); }
int n::C::m() const { return v + h(1); }
int n::C::s() { return count; }
bool n::C::operator==(const C &o) const { return v == o.v; }
template <class T> T n::B<T>::get() const { return t + 1; }
template <class T> T n::B<T>::make(T x) { return x * 2; }
n::O2::I2::I2() : w(8) {}
int n::O2::I2::g() const { return w + 1; }
int Outer::Inner::f() { return w * 2; }
int main() {
  std::printf("%d %d %d %d\n", n::f(), n::g, n::h(2), n::in::k());
  {
    n::C c, d;
    std::printf("%d %d %d %d\n", c.m(), n::C::s(), (int) (c == d), n::C::count);
  }
  n::B<int> b{41};
  n::O2::I2 i2;
  Outer::Inner oi;
  std::printf("%d %d %d %d\n", b.get(), (int) n::B<long>::make(21), i2.g(), oi.f());
  return 0;
}
