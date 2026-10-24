#include <algorithm>
#include <cstdio>
#include <string>
#include <tuple>
#include <utility>
#include <vector>
// the program's own functions named as std's function templates are -- size, find, swap, begin, count, apply -- and
// std's own beside them, std::get and std::size among them
struct Bag {
  int n;
};
static int size(const Bag &b) { return b.n; }
static int find(const Bag &b, int k) { return b.n == k ? 1 : 0; }
static void swap(Bag &a, Bag &b) { int t = a.n; a.n = b.n; b.n = t; }
static int begin(int k) { return k + 100; }
static int count(int a, int b) { return a * b; }
static int apply(int x) { return x - 1; }
int main() {
  Bag a{3}, b{5};
  swap(a, b);
  std::vector<int> v = {4, 1, 3};
  std::sort(v.begin(), v.end());
  std::tuple<int, std::string> t(7, "x");
  auto it = std::find(v.begin(), v.end(), 3);
  std::printf("%d %d %d %d %d %d\n", size(a), find(b, 3), begin(1), count(2, 3), apply(9), (int) (it - v.begin()));
  std::printf("%d %s %zu\n", std::get<0>(t), std::get<1>(t).c_str(), std::size(v));
  return 0;
}
