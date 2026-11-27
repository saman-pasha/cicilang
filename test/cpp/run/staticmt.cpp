// staticmt.cpp (1.6.27): static member templates called with the class's name -- a pack, a default, an overload set of a
// plain function and a template -- beside a namespace's pack: the class's static road takes them, and 1.6.26's rules of a
// member named with its class that none takes, and of a member with no object, leave member templates to it
#include <cstdio>
struct S {
  template <class... A> static int f(A... a) { return (int)sizeof...(a); }
  template <class T> static int g(T a, int k = 2) { return (int)a * k; }
  static int h(int a) { return a; }
  template <class T> static int h(T a, T b) { return (int)(a + b); }
};
namespace n { template <class... A> int c(A... a) { return (int)sizeof...(a); } }
int main() { std::printf("%d %d %d %d %d %d %d\n", S::f(), S::f(1, 2, 3), S::g(3), S::g(3, 3), S::h(4), S::h(1, 2), n::c(1, 2)); return 0; }
