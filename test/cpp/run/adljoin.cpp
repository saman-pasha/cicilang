// argument-dependent lookup joined with ordinary lookup ([basic.lookup.argdep]; 1.6.22): where two of the program's
// namespaces declare one function name, a call of an argument of a namespace's class ranks that namespace's overloads
// with the global ones, and a parenthesized name looks in no argument's namespace. Until 1.6.22 `g(a)' called `g(...)'
#include <cstdio>
namespace N {
  struct A { int k = 1; };
  int g(A) { return 1; }
  int h(A, long) { return 10; }
  int w(int) { return 40; }
}
namespace M { struct B { int k = 2; }; int g(B) { return 3; } }
int g(...) { return 2; }
int h(N::A, int) { return 20; }
int w(int) { return 30; }
int main() {
  N::A a;
  M::B b;
  std::printf("%d %d %d %d\n", g(a), (g)(a), g(b), (g)(b));
  std::printf("%d %d %d\n", h(a, 1), h(a, 1L), w(5));
  return 0;
}
