// A constexpr body's free names are the file's, never its caller's locals ([basic.lookup.unqual]; 0.257), and an
// immediately invoked lambda initializes a constant, a local's or a file-scope one's (0.257); one with an effect
// stays a run-time initialization
#include <cstdio>
struct A { int x, y; };
constexpr A a = {1, 2};
constexpr int gx() { return a.x * 10; }
constexpr int K = 1;
constexpr int gk() { return K; }
int f1() { constexpr A a = {3, 4}; static_assert(gx() == 10); const int y = gx(); return y + a.y; }
int f2() { const int K = 5; static_assert(gk() == 1); const int z = gk(); return z + K; }
int f3() { int K = 5; A a = {7, 8}; static_assert(gk() == 1 && gx() == 10); return K + a.x; }
struct Q { int x, y; };
constexpr Q q = [] { return Q{1, 2}; }();
static_assert(q.x == 1 && q.y == 2);
constexpr int n = [] { int s = 0; for (int i = 1; i <= 4; ++i) s += i; return s; }();
static_assert(n == 10);
int f4() {
  constexpr auto c = [] { return 3 + 4; }();
  static_assert(c == 7);
  constexpr Q r = [] { Q t{3, 4}; t.y += 10; return t; }();
  static_assert(r.y == 14);
  return c + r.y;
}
int x = [] { std::puts("init x"); return 1; }();
int main() {
  const int y = [] { std::puts("init y"); return 2; }();
  std::printf("%d %d %d %d %d %d %d\n", f1(), f2(), f3(), q.x + q.y, n, f4(), x + y);
}
