// A local's noted aggregate or constexpr object is an entry of the frame that declares it (0.257): a parameter or a
// local of its name -- in a later function, an inner block, an instance made in the middle of its body -- hides it,
// and it hides a file-scope constant of its name only while it is in scope ([basic.scope.block]/2, [expr.const]/4)
#include <cstdio>
struct P { int x, y; constexpr P(int a, int b) : x(a), y(b) {} };
struct A { int x, y; };
constexpr int sq(int v) { return v * v; }
constexpr A a = {1, 2};
int f1() { constexpr P p(3, 4); static_assert(p.x == 3); return p.y; }
int g1(P p) { const int y = sq(p.x); return y; }
int f2() { constexpr A q = {3, 4}; static_assert(q.x == 3); return q.y; }
int g2(A q) { const int y = sq(q.x); return y; }
template <class T> int h(T v) { int p = v + 1; return p; }
int k() { constexpr P p(3, 4); int r = h(1); static_assert(p.x == 3); return r + p.y; }
int f3() { constexpr A a = {3, 4}; static_assert(a.x == 3); return a.y; }
static_assert(a.x == 1);
constexpr int gx() { return a.x * 10; }
int f4() {
  constexpr P p(1, 2);
  int r = 0;
  { constexpr P p(7, 8); static_assert(p.x == 7); r += p.y; }
  static_assert(p.x == 1);
  for (int p = 0; p < 2; ++p) r += p;
  static_assert(p.y == 2);
  return r + p.x;
}
int main() {
  P p(5, 6);
  A q = {5, 6};
  static_assert(gx() == 10);
  std::printf("%d %d %d %d %d %d %d %d\n", f1(), g1(p), f2(), g2(q), k(), f3(), gx(), f4());
}
