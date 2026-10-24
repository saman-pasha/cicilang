#include <cmath>
#include <cstdio>
// a function-local static scalar: a constant, a constexpr call's, a run-time one (a call, a variable's value, a library
// function's), each once
static int calls = 0;
static int f(int k) { ++calls; return k * 10; }
constexpr int sq(int x) { return x * x; }
static int glob = 7;
static int g(int k) {
  static int a = 5;
  static const int b = sq(3);
  static int c = f(k);
  static int d = glob + k;
  static double e = std::sqrt(16.0 + k);
  static int *p = &glob;
  static long m = c * 2L;
  a += 1;
  return a + b + c + d + (int) e + *p + (int) m;
}
int main() {
  int r1 = g(1);
  int r2 = g(2);
  std::printf("%d %d %d\n", r1, r2, calls);
  return 0;
}
