// A qualified data member inside a member function is that member of `this' ([class.mfct.non.static]/2):
// `C::m' with C the class or a base of it reaches the base sub-object's member. libc++ 18's
// `formatter<const _CharT *, _CharT>::format' reads `_Base::__parser_' through its base alias.
#include <cstdio>
struct P { int v = 3; int get() const { return v * 2; } };
struct B { P p_; int n = 4; };
struct D : B {
  using Base = B;
  int n = 9;
  int f() const { return Base::p_.get() + B::n + n + D::n; }
  void set(int a) { B::n = a; Base::p_.v = a + 1; }
};
template <class T> struct TB { T x{}; };
template <class T> struct TD : TB<T> {
  using _Base = TB<T>;
  T g() const { return _Base::x + 1; }
  void put(T v) { _Base::x = v; }
};
struct X { int a = 1; };
struct Y { int a = 2; };
struct XY : X, Y { int sum() const { return X::a * 10 + Y::a; } void bump() { Y::a += 5; } };
struct L : B { int via() { auto f = [this] { return B::n * 3 + Base::p_.v; }; return f(); } using Base = B; };
int main() {
  D d;
  std::printf("%d\n", d.f());
  d.set(10);
  std::printf("%d\n", d.f());
  TD<int> t;
  std::printf("%d\n", t.g());
  t.put(41);
  std::printf("%d\n", t.g());
  XY xy;
  xy.bump();
  std::printf("%d\n", xy.sum());
  L l;
  std::printf("%d\n", l.via());
  return 0;
}
