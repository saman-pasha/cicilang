// std::valarray (C++17): arithmetic through its expression templates, a slice, sum and max.
#include <cstdio>
#include <valarray>
int main() {
  std::valarray<int> a{1, 2, 3, 4, 5, 6};
  std::valarray<int> b = a * 2 + 1;
  std::valarray<int> c = a[std::slice(1, 3, 2)];
  std::printf("%d %d %d %d %zu\n", b[0], b[5], b.sum(), c.max(), c.size());
  return 0;
}
