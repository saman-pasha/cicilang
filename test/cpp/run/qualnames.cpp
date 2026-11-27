// qualnames.cpp (1.6.27): qualified calls that name something, beside 1.6.27's rule of a qualified name that nothing
// declares: a namespace's function object, class, typedef, function template, plain struct and enumeration, a name that
// two namespaces declare, a nested namespace's function and a function that a using of a namespace names
#include <cstdio>
namespace n {
  struct Add { int operator()(int a, int b) const { return a + b; } };
  Add add;
  struct Box { int v; Box(int x) : v(x * 2) {} };
  typedef long L;
  template <class T> T twice(T a) { return a + a; }
  struct P { int x, y; };
  enum Color { red = 3, green };
  int same(int a) { return a + 1; }
  namespace in { int deep(int a) { return a * 7; } }
}
namespace m { int same(int a) { return a + 2; } }
namespace u { int used(int a) { return a - 1; } }
namespace w { using namespace u; }
int main() {
  n::Box b = n::Box(4); n::P p = n::P{1, 2};
  std::printf("%d %d %ld %d %d %d\n", n::add(2, 3), b.v, n::L(7), n::twice(5), p.x + p.y, (int)n::Color(4));
  std::printf("%d %d %d %d %d\n", n::same(1), m::same(1), n::in::deep(2), w::used(9), (int)n::red);
  return 0;
}
