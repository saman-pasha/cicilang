// a nearly empty primary whose virtual bases lie outside it, while each part is built and destroyed, in the deeper shapes: the
// calls and typeid in each constructor and destructor, the order of the parts, and a class built over each as a virtual base
#include <cstdio>
#include <typeinfo>
struct A { int a = 1; A() { std::printf("A() %d %s\n", fa(), typeid(*this).name()); } virtual int fa() { return 10 + a; } virtual ~A() { std::printf("~A %d\n", fa()); } };
struct M { M() { std::printf("M() %d %s\n", m(), typeid(*this).name()); } virtual int m() { return 6; } virtual ~M() { std::printf("~M %d\n", m()); } };
struct N2 : virtual M {
  N2() { std::printf("N2() %d %d %s %s\n", n(), ((M *) this)->m(), typeid(*this).name(), typeid(*(M *) this).name()); }
  ~N2() override { std::printf("~N2 %d %d\n", n(), ((M *) this)->m()); }
  virtual int n() { return 7; } int m() override { return 60 + n(); }
};
struct J2 : virtual N2, virtual A {
  J2() { std::printf("J2() %d %d %d %d %s %s\n", j(), ((N2 *) this)->n(), ((M *) this)->m(), ((A *) this)->fa(), typeid(*(M *) this).name(), typeid(*(A *) this).name()); }
  ~J2() override { std::printf("~J2 %d %d %d\n", j(), ((M *) this)->m(), ((A *) this)->fa()); }
  virtual int j() { return 8; } int n() override { return 70 + j(); }
};
struct G : virtual J2 {
  int g = 9;
  G() { std::printf("G() %d %d %d %s\n", ((M *) this)->m(), ((A *) this)->fa(), j(), typeid(*(N2 *) this).name()); }
  ~G() override { std::printf("~G %d %d\n", ((M *) this)->m(), ((A *) this)->fa()); }
  int j() override { return 80 + g; } int fa() override { return 90 + g + a; }
};
struct H : G { int h = 2; H() { std::printf("H() %d %d %s\n", ((M *) this)->m(), ((A *) this)->fa(), typeid(*(J2 *) this).name()); } ~H() override { std::printf("~H %d\n", ((M *) this)->m()); } int m() override { return 100 + h; } };
struct I : virtual A {
  I() { std::printf("I() %d %d %s %s\n", f(), ((A *) this)->fa(), typeid(*this).name(), typeid(*(A *) this).name()); }
  ~I() override { std::printf("~I %d %d\n", f(), ((A *) this)->fa()); }
  virtual int f() { return 2; } int fa() override { return 20 + a; }
};
struct P1 { int p = 3; P1() { std::printf("P1() %d\n", fp()); } virtual int fp() { return 30 + p; } virtual ~P1() { std::printf("~P1 %d\n", fp()); } };
struct X1 : P1, virtual I { int x = 4; X1() { std::printf("X1() %d %d %d %s\n", f(), ((A *) this)->fa(), fp(), typeid(*(I *) this).name()); } ~X1() override { std::printf("~X1 %d\n", f()); } int f() override { return 40 + x; } int fp() override { return 45 + x; } };
struct F1 : virtual X1 { int g = 5; F1() { std::printf("F1() %d %d %d\n", ((I *) this)->f(), ((A *) this)->fa(), ((P1 *) this)->fp()); } ~F1() override { std::printf("~F1 %d\n", ((A *) this)->fa()); } int fa() override { return 50 + g + a; } };
struct W : virtual I { int w = 3; W() { std::printf("W() %d %d %s\n", f(), ((A *) this)->fa(), typeid(*(I *) this).name()); } ~W() override { std::printf("~W %d\n", f()); } int f() override { return 110 + w; } };
struct K2 : virtual W { int k = 4; K2() { std::printf("K2() %d %d\n", ((I *) this)->f(), ((A *) this)->fa()); } ~K2() override { std::printf("~K2 %d\n", ((A *) this)->fa()); } int fa() override { return 120 + k + a; } };
struct Z : virtual G { int z = 1; Z() { std::printf("Z() %d %d\n", ((M *) this)->m(), ((A *) this)->fa()); } int m() override { return 130 + z; } };
int main() {
  { G g; std::printf("in G %d %d\n", ((M *) &g)->m(), ((N2 *) &g)->n()); }
  { H h; std::printf("in H %d %d\n", ((M *) &h)->m(), ((A *) &h)->fa()); }
  { F1 f; std::printf("in F1 %d %d\n", ((I *) &f)->f(), ((P1 *) &f)->fp()); }
  { K2 k; std::printf("in K2 %d %d\n", ((W *) &k)->f(), ((A *) &k)->fa()); }
  { Z z; std::printf("in Z %d %d %zu\n", ((M *) &z)->m(), ((J2 *) &z)->j(), sizeof(Z)); }
  M *p = new H; delete p; A *q = new F1; delete q;
  return 0;
}
