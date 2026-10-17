// libc++ 21's vectorized mismatch (simd_utils.h, the road __OPTIMIZE_SIZE__ turned off until 0.162): four vectors a turn,
// then one, then the last vector back from the end, then lane by lane -- a mismatch at every kind of place, the element
// sizes 1, 2, 4 and 8, pointers through the aliasing iterator, and a vector's operator< over lexicographical_compare
#include <algorithm>
#include <cstdio>
#include <vector>
int main() {
  std::vector<int> a(100), b(100);
  for (int i = 0; i < 100; ++i) a[i] = b[i] = i * 7;
  for (int at : {0, 3, 15, 16, 17, 31, 63, 64, 70, 95, 97, 99}) {
    b[at] = -1;
    std::printf("%d ", (int) (std::mismatch(a.begin(), a.end(), b.begin()).first - a.begin()));
    b[at] = a[at];
  }
  std::printf("none %d\n", (int) (std::mismatch(a.begin(), a.end(), b.begin()).first - a.begin()));
  std::vector<int> e(5, 1), f(5, 1); f[4] = 2;
  std::printf("short %d\n", (int) (std::mismatch(e.begin(), e.end(), f.begin()).first - e.begin()));
  std::vector<unsigned char> c(70, 1), d(70, 1); d[65] = 2;
  std::vector<short> s(40, 1), t(40, 1); t[21] = 2;
  std::vector<long long> l(40, 1), m(40, 1); m[9] = 2;
  std::printf("sizes %d %d %d\n", (int) (std::mismatch(c.begin(), c.end(), d.begin()).first - c.begin()),
              (int) (std::mismatch(s.begin(), s.end(), t.begin()).first - s.begin()),
              (int) (std::mismatch(l.begin(), l.end(), m.begin()).first - l.begin()));
  std::vector<int> x(50, 3), y(50, 3); y[47] = 4;
  std::printf("less %d %d %d\n", (int) (x < y), (int) (y < x), (int) (x == y));
  int k1, k2;
  std::vector<int *> p(20, &k1), q(20, &k1); q[18] = &k2;
  std::printf("ptr %d\n", (int) (std::mismatch(p.begin(), p.end(), q.begin()).first - p.begin()));
  return 0;
}
