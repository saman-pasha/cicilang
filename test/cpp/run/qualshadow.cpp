// qualshadow.cpp (1.6.27): a qualified call of a function whose name a local shares -- a namespace's function and
// template, one that a using names, the global one, a C function through std:: and :: -- calls the function, and the
// local keeps its value after the call: the call was the local's, `not lowered yet: call(id(g))', and a C function's
// declaration went into the local's frame over it; a template's own local of its name is its body's, while the call
// that instantiates it resolves
#include <cstdio>
namespace n { int g(int a) { return a * 10; } template <class T> int t(T a) { return (int)a + 100; }
              template <class T> int u(T a) { int u = (int)a * 2; return u + 1; } }
int h(int a) { return a + 1000; }
namespace m { using ::h; }
int main() {
  double g = 1.5; int t = 2; int h = 3; int puts = 4;
  int r1 = n::g(2), r2 = n::t(3), r3 = ::h(4), r4 = m::h(5), u = n::u(4);
  std::puts("one"); ::puts("two");
  std::printf("%d %d %d %d %.1f %d %d %d %d\n", r1, r2, r3, r4, g, t, h, puts, u);
  return puts - 4;
}
