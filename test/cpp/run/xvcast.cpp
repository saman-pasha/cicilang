#include <cstdio>
#include <utility>
// an xvalue cast of a scalar in every position: an operand, an initializer, an argument by value, by reference, a pointer
static int byval(int v) { return v * 2; }
static int byref(int &&v) { v += 1; return v; }
static int over(int &) { return 1; }
static int over(int &&) { return 2; }
static long over2(const long &) { return 1; }
static long over2(long &&) { return 2; }
int main() {
  int x = 5;
  int y = static_cast<int &&>(x) + 1;
  int z = static_cast<int &&>(x);
  int a = byval(static_cast<int &&>(x));
  int b = byref(static_cast<int &&>(x));
  int arr[3] = {7, 8, 9};
  int *p = arr;
  int *q = static_cast<int *&&>(p);
  int c = *static_cast<int *&&>(p) + q[1];
  long l = 4;
  std::printf("%d %d %d %d %d %d %d %d %ld\n", y, z, a, b, x, c, over(static_cast<int &&>(x)), over(x), over2(static_cast<long &&>(l)));
  bool t = true;
  bool u = static_cast<bool &&>(t) && static_cast<int &&>(x) > 3;
  double d = 1.5;
  double e = static_cast<double &&>(d) * 2;
  std::printf("%d %g %d\n", (int) u, e, static_cast<int &&>(x) ? 1 : 0);
  return 0;
}
