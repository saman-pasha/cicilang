// a temporary's operator() called as a statement, `Loop()(a, b);': a call, never a declaration of nothing
// ([dcl.decl]/1), as libc++ 18's ranges::copy calls `__copy_loop<_AlgPolicy>()(first, last, result)'
#include <cstdio>
int total = 0;
struct Add { void operator()(int a, int b) const { total += a + b; } };
template <class P> struct Twice { template <class T> void operator()(T &x) const { x *= 2; } };
struct Mark { int operator()() const { return ++total; } };
int main() {
  Add()(1, 2);
  Add{}(3, 4);
  int v = 5;
  Twice<int>()(v);
  Mark()();
  std::printf("%d %d\n", total, v);
  return 0;
}
