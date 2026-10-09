// USING-DECLARED MEMBER FUNCTIONS (0.121; [namespace.udecl]): `using Base::f;' joins the base's overloads to the class's own, and the
// call chooses over all of them -- the base's exact match beats the class's conversion; a function the class declares itself with the same
// parameters hides the base's; the pack form `using Bs::operator()...;' does it for every base. A virtual name keeps its dispatch.
#include <cstdio>
struct B {
  int base;
  B() : base(10) {}
  int f(int x) { return x + base; }
  int f(double d) { return (int) (d * 2) + base; }
  int g(int x) const { return x * 3; }
  virtual int v() { return 4; }
  static int s(int x) { return x + 100; }
};
struct D : B {
  using B::f;
  using B::g;
  using B::v;
  int f(const char *p) { return p[0]; }
  int g(int x) const { return x * 5; }     // hides B::g(int)
  int v() override { return 40; }
};
struct One { template <class T> int operator()(T x, int y) const { return (int) x + y; } };
struct Two { template <class T, class U> int operator()(T &&x, U &&y) const { return (int) x * (int) y; } };
template <class... Bs> struct All : Bs... { using Bs::operator()...; void operator()() const { std::printf("none\n"); } };
struct A1 { int operator()(int) const { return 1; } };
struct B1 { int operator()(double) const { return 20; } };
template <class... Bs> struct Pick : Bs... { using Bs::operator()...; };
int main() {
  D d;
  const D &cd = d;
  B &b = d;
  std::printf("%d %d %d\n", d.f(1), d.f(2.5), d.f("A"));
  std::printf("%d %d %d\n", d.g(2), cd.g(2), b.v());
  std::printf("%d\n", d.s(1));
  All<One, Two> a;
  a();
  std::printf("%d\n", a(2, 3));
  std::printf("%d\n", a(2.5, 3.5));
  Pick<A1, B1> p;
  std::printf("%d %d\n", p(1), p(2.0));
  return 0;
}
