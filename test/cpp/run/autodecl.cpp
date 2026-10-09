// `auto' with several declarators (0.117): `auto it = v.begin(), e = v.end();' is two declarations, each deduced alone. The reader read
// the first initializer as an EXPRESSION, so the comma took the second declarator for a part of it and the declaration named one
// variable with a comma expression for its value (`not lowered yet: auto(q)'); found by <complex>
#include <cstdio>
#include <vector>
struct P { int x; P(int v) : x(v) {} P operator+(const P &o) const { return P(x + o.x); } };
auto top1 = 5, top2 = top1 * 3;
int main() {
  P a(1), b(2);
  auto c = a + b, d = b + b;
  std::printf("%d %d\n", c.x, d.x);
  auto n = 3, m = n * 2;
  auto &r = n, &s = m;
  r += 1;
  std::printf("%d %d %d %d\n", n, m, r, s);
  std::vector<int> v = {4, 5, 6};
  auto it = v.begin(), e = v.end();
  int t = 0;
  for (; it != e; ++it) t += *it;
  std::printf("%d\n", t);
  auto x = 1.5, y = x * 2;
  std::printf("%g %g %d %d\n", x, y, top1, top2);
  return 0;
}
