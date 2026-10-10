// What a lambda that is not mutable may do with its by-value captures (0.127): read them, call their const member functions, hand them
// to a const reference; a mutable lambda and a reference capture write. The closure's operator() is const.
#include <cstdio>
#include <vector>
#include <algorithm>
struct Counter { int n = 0; void bump() { ++n; } int get() const { return n; } };
int main() {
  Counter c; int k = 2; std::vector<int> v{3, 1, 2};
  auto f = [c]() mutable { c.bump(); return c.get(); };
  auto g = [&c]() { c.bump(); return c.get(); };
  auto h = [c, k]() { return c.get() + k; };
  auto s = [v]() { return (int) v.size() + v[0]; };
  const auto cf = [k](int a) { return a * k; };
  std::sort(v.begin(), v.end(), [k](int a, int b) { return a * k < b * k; });
  std::printf("%d %d %d %d %d %d %d\n", f(), f(), g(), h(), s(), cf(4), v[0]);
  return 0;
}
