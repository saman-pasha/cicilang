// the program's namespace names that the library declares too (0.221): keyed apart from the library's -- a qualified call
// finds its own namespace's, a bare use in a nested namespace the enclosing one's, and an unqualified call over the program's
// class its namespace's by argument-dependent lookup, the library's algorithms too
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <utility>
namespace ns {
  struct V { int v; };
  int max(int a, int b) { return a + b; }
  int abs(int x) { return x + 100; }
  int abs(V x) { return x.v + 200; }
  int swaps = 0;
  void swap(V &a, V &b) { ++swaps; int t = a.v; a.v = b.v; b.v = t; }
  namespace detail { int g() { return max(1, 2); } }
}
int main() {
  std::printf("%d %d %d\n", ns::max(2, 3), std::max(2, 3), ns::detail::g());
  std::printf("%d %d %d\n", ns::abs(-4), std::abs(-4), abs(ns::V{-5}));
  ns::V a{1}, b{2};
  swap(a, b); std::printf("%d %d %d\n", a.v, b.v, ns::swaps);
  std::swap(a, b); std::printf("%d %d %d\n", a.v, b.v, ns::swaps);
  ns::V arr[3] = {{3}, {1}, {2}}; std::iter_swap(arr, arr + 2); std::printf("%d %d %d\n", arr[0].v, arr[2].v, ns::swaps);
  return 0;
}
