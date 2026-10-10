#include <algorithm>
#include <cstdio>
int main() {
  int a[3] = {1, 2, 3}, b[3] = {1, 2, 4};
  auto r = std::mismatch(a, a + 3, b, b + 3);
  std::printf("%d %d\n", (int)(r.first - a), *r.second);
  return 0;
}
