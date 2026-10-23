// A qualification conversion is worse than the identity ([over.ics.rank]/3.2.5; 0.191): of two function templates that both take a
// pointer argument, the one that adds no `const' to its pointee wins, and where both take it as it is, the more specialized
// (libc++'s `any_cast(const any *)' calls `any_cast(any *)' through a const_cast, and called itself)
#include <cstdio>
struct A { int v; };
template <class T> int f(T *) { return 1; }
template <class T> int f(const T *) { return 2; }
template <class R> int g(const A *a) { return 10 + g<R>(const_cast<A *>(a)); }
template <class R> int g(A *a) { return a->v; }
template <class T> int h(const volatile T *) { return 3; }
template <class T> int h(const T *) { return 4; }
int k(const A *) { return 5; }
int k(A *) { return 6; }
int main() {
  A a{7};
  int i = 0;
  const int ci = 0;
  A *pa = &a;
  const A *pc = &a;
  std::printf("%d %d %d %d\n", f(&i), f(&ci), f(pa), f(pc));
  std::printf("%d %d\n", g<int>(pc), g<int>(pa));
  std::printf("%d %d\n", h(&i), h(&ci));
  std::printf("%d %d\n", k(pa), k(pc));
  return 0;
}
