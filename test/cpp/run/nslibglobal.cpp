// the program's global names beside the library's (0.221): a call qualified by std finds none of the program's own functions
// of the name -- a function, a function template, a function over the program's class -- and an unqualified call keeps the
// program's; argument-dependent lookup of the program's names through a pointer's pointee and a template's argument
#include <algorithm>
#include <cstdio>
#include <utility>
#include <vector>
struct P { int v; bool operator<(const P &o) const { return v < o.v; } };
struct Box { int v; };
int max(int a, int b) { return a + b; }
template <class T> T min(T a, T b) { return b; }
P min(P a, P b) { return P{a.v + b.v}; }
int swaps = 0;
void swap(Box &a, Box &b) { ++swaps; int t = a.v; a.v = b.v; b.v = t; }
namespace ns {
struct S { int v; };
int count(const S *p) { return p->v + 10; }
int size(const std::vector<S> &v) { return (int)v.size() + 100; }
}
int main() {
  std::printf("%d %d %d\n", max(2, 3), std::max(2, 3), ::max(2, 3));
  std::printf("%d %d %d %d\n", min(2, 3), std::min(2, 3), min(P{1}, P{2}).v, std::min(P{1}, P{2}).v);
  Box a{1}, b{2};
  swap(a, b);
  std::printf("%d %d %d\n", a.v, b.v, swaps);
  std::swap(a, b);
  std::printf("%d %d %d\n", a.v, b.v, swaps);
  ns::S s{5};
  std::vector<ns::S> v(3);
  std::printf("%d %d %d\n", count(&s), size(v), (int)std::size(v));
  return 0;
}
