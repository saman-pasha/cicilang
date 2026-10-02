// An init-capture, [n = e] and [&r = e] ([expr.prim.lambda.capture]/6): a closure member of e's type decayed, or a
// reference bound to e, initialized in the enclosing scope.
#include <cstdio>
int main() {
  auto g = [n = 5, m = 2]() { return n * 10 + m; };
  int k = 3;
  auto h = [&r = k]() { r += 1; return r; };
  int v = h();
  std::printf("%d %d %d\n", g(), v, k);
  return 0;
}
