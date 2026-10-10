#include <cstdio>
template <class I1, class I2, class P> int f(I1, I1, I2, P) { return 1; }
template <class I1, class I2> int f(I1, I1, I2, I2) { return 2; }
template <class I1, class I2> int g(I1, I1, I2, I2) { return 2; }
template <class I1, class I2, class P> int g(I1, I1, I2, P) { return 1; }
int main() {
  int a[3] = {1, 2, 3};
  int *p = a;
  std::printf("%d %d %d %d\n", f(p, p, p, p), g(p, p, p, p), f(p, p, p, 1), g(p, p, p, 1));
  return 0;
}
