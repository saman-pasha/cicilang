// A namespace-scope object and a static data member defined out of its class, initialized by a prvalue of the class
// written as its constructor's call: the prvalue IS the object (C++17), constructed from its own arguments, at
// compile time where the constructor is constexpr, else before main, its destructor run after main.
#include <cstdio>

struct O {                     // no default constructor
  int v;
  constexpr O(int x) : v(x * 2) {}
  static const O low;
  static const O high;
  static const O mid;
};
const O O::low = O(3);
const O O::high = O{4};
const O O::mid(5);

struct K {                     // a copy constructor that shows a copy
  int v;
  constexpr K() : v(-1) {}
  constexpr K(int x) : v(x) {}
  constexpr K(const K &o) : v(o.v + 100) {}
};

struct P {                     // constructed and destroyed at run time
  int v;
  P(int x) : v(x * 3) { std::printf("P(%d)\n", x); }
  ~P() { std::printf("~P %d\n", v); }
  static const P one;
};
const P P::one = P(1);

const O g1 = O(6);
O g2 = O{7};
static const O g3 = O(8);
const K k1 = K(9);
K k2 = K{10};
const P p2 = P(2);
P p3 = P{3};
P p4(4);

int main() {
  std::printf("%d %d %d\n", O::low.v, O::high.v, O::mid.v);
  std::printf("%d %d %d\n", g1.v, g2.v, g3.v);
  std::printf("%d %d\n", k1.v, k2.v);
  std::printf("%d %d %d %d\n", P::one.v, p2.v, p3.v, p4.v);
  g2.v += 1;
  std::printf("%d\n", g2.v);
  return 0;
}
