// A braced default member initializer of a class member is list-initialization, and an aggregate's member with no item
// takes its own default member initializer ([dcl.init.aggr]/5): libc++ 18's format-spec parser holds
// `__code_point<_CharT> __fill_{}' over `struct __code_point<char> { char __data[4] = {' '}; }'.
#include <cstdio>
template <class C> struct Point { C data[4] = {' '}; int n = 2; };
struct Ctor { int v; Ctor() : v(5) {} Ctor(int a, int b) : v(a * b) {} };
template <class C> struct Parser {
  Point<C> fill_{};
  Ctor c_{};
  Ctor d_{3, 4};
  int w_{9};
};
int main() {
  Parser<char> p;
  Point<char> q{};
  Point<char> r{{'x'}};
  std::printf("%d %d %d %d %d %d %d %d %d\n", (int) p.fill_.data[0], (int) p.fill_.data[1], p.fill_.n, p.c_.v, p.d_.v, p.w_,
              (int) q.data[0], q.n, (int) r.data[0]);
  return 0;
}
