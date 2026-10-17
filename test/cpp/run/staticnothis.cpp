// A STATIC MEMBER FUNCTION TAKES NO `this' (0.160): called bare, qualified, through an object, by its address, a template's, a constexpr one
#include <cstdio>
struct M {
  int k = 5;
  static int twice(int x) { return 2 * x; }
  static int sum(int a, int b);
  template <class T> static T neg(T v) { return -v; }
  static constexpr int cube(int x) { return x * x * x; }
  int use() const { return twice(k) + sum(k, 1); }
};
int M::sum(int a, int b) { return a + b + twice(1); }
struct N { static long big(long a, long b, long c, long d, long e, long f, long g) { return a + b + c + d + e + f + g; } };
static int apply(int (*f)(int), int v) { return f(v); }
int main() {
  M m;
  int (*p)(int, int) = &M::sum;
  static_assert(M::cube(3) == 27, "");
  std::printf("%d %d %d %d\n", M::twice(4), m.twice(5), m.use(), p(2, 3));
  std::printf("%d %.1f %d %ld\n", M::neg<int>(7), M::neg(2.5), apply(M::twice, 21), N::big(1, 2, 3, 4, 5, 6, 7));
  return M::cube(2);
}
