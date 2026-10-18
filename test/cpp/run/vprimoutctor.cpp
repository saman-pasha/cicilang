// a nearly empty primary whose virtual base lies outside it, while each part is built and destroyed: the calls and typeid in each
// constructor and destructor, and in a class derived from it and one over it as a virtual base
#include <cstdio>
#include <typeinfo>
struct A { int a = 1; A() { std::printf("A() %d %s\n", fa(), typeid(*this).name()); } virtual int fa() { return 10 + a; } virtual ~A() { std::printf("~A %d\n", fa()); } };
struct I : virtual A {
  I() { std::printf("I() %d %d %s %s\n", f(), ((A *) this)->fa(), typeid(*this).name(), typeid(*(A *) this).name()); }
  ~I() override { std::printf("~I %d %d\n", f(), ((A *) this)->fa()); }
  virtual int f() { return 2; } int fa() override { return 20 + a; }
};
struct C : virtual I {
  int c = 3;
  C() { std::printf("C() %d %d %d %s\n", f(), ((A *) this)->fa(), k(), typeid(*(A *) this).name()); }
  ~C() override { std::printf("~C %d %d\n", f(), ((A *) this)->fa()); }
  int f() override { return 30 + c; } virtual int k() { return 4; }
};
struct D : C { int d = 5; D() { std::printf("D() %d %d %d\n", ((I *) this)->f(), ((A *) this)->fa(), k()); } int fa() override { return 50 + d; } int k() override { return 70 + d; } };
struct E : virtual C { int e = 6; E() { std::printf("E() %d %d %d\n", ((I *) this)->f(), ((A *) this)->fa(), ((C *) this)->k()); } int k() override { return 60 + e; } int f() override { return 80 + e; } };
int main() {
  { C c; std::printf("in C %d %d\n", ((I *) &c)->f(), ((A *) &c)->fa()); }
  { D d; std::printf("in D %d %d %d\n", ((I *) &d)->f(), ((A *) &d)->fa(), ((C *) &d)->k()); }
  { E e; std::printf("in E %d %d %d %zu\n", ((I *) &e)->f(), ((A *) &e)->fa(), ((C *) &e)->k(), sizeof(E)); }
  A *p = new E; delete p;
  return 0;
}
