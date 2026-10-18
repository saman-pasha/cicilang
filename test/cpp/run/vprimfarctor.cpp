// a primary further in that no base takes, while each part is built and destroyed: `D : virtual X' over `X : P, virtual I'
#include <cstdio>
#include <typeinfo>
struct P { virtual int p() { return 5; } int pd = 6; };
struct I { virtual int f() { return 1; } virtual ~I() { std::printf("~I %d\n", f()); } };
struct X : P, virtual I {
  int x = 2;
  X() { std::printf("X() %d %d %s %s\n", ((I *) this)->f(), p(), typeid(*(I *) this).name(), typeid(*(P *) this).name()); }
  ~X() override { std::printf("~X %d %d\n", ((I *) this)->f(), p()); }
  int f() override { return 20 + x; } int p() override { return 50 + pd; }
};
struct D : virtual X { int d = 3; D() { std::printf("D() %d %d %s\n", ((I *) this)->f(), ((P *) this)->p(), typeid(*(I *) this).name()); } int p() override { return 80 + d; } };
struct E : D { int e = 4; int f() override { return 90 + e; } };
int main() {
  { D d; std::printf("in D %d %d\n", ((I *) &d)->f(), ((P *) &d)->p()); }
  { E e; std::printf("in E %d %d %zu %zu\n", ((I *) &e)->f(), ((P *) &e)->p(), sizeof(D), sizeof(E)); }
  I *q = new E; std::printf("new E %d\n", q->f()); delete q;
  return 0;
}
