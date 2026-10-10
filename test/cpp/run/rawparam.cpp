// A library function template's result that names the template's own parameter, `_Tp *' for std::addressof, when a block typedef in the unit is also
// called `_Tp': a typedef in a block joins the unit's one table, and the raw argument `std::addressof(ctr_)' of a BASE's initializer came out as `int *'.
#include <cstdio>
#include <memory>
int dummy() { using _Tp = int; _Tp v = 3; return v; }
int other() { typedef double _Up; _Up w = 1.5; return (int) w; }
struct Counter { long c; };
struct Base {
  explicit Base(Counter *p) : v_(p ? 1 : 0) {}
  explicit Base(int n) : v_(n + 100) {}
  long v_;
};
struct Derived : Base {
  Derived() : Base{std::addressof(ctr_)}, ctr_{5} {}
  Counter ctr_;
};
struct Boxed : Base {
  Boxed() : Base(std::addressof(box_)), box_{9} {}
  Counter box_;
};
struct Third : Base {
  Third() : Base(2) {}
};
int main() {
  Derived d;
  Boxed p;
  Third t;
  std::printf("%ld %ld %ld %ld %d %d\n", d.v_, d.ctr_.c, p.v_, t.v_, dummy(), other());
  return 0;
}
