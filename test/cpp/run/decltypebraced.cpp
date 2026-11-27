// a braced functional cast to a decltype type (1.6.31; [expr.type.conv]/2): an aggregate's, a scalar's, a class's constructor's,
// a vector's through its initializer_list constructor, an empty one and a designated one -- each was `syntax error: could
// not read this item', where the parenthesized cast was read since 1.6.22
#include <cstdio>
#include <vector>
struct M { int a; };
struct N { int a, b; N(int x, int y) : a(x), b(y) {} };
int main() {
  M mm{1}; auto x = decltype(mm){2};
  int k = 0; auto y = decltype(k){5};
  N n{1, 2}; auto z = decltype(n){3, 4};
  std::vector<int> v; auto w = decltype(v){7, 8};
  auto e = decltype(k){};
  auto d = decltype(mm){.a = 9};
  std::printf("%d %d %d %d %zu %d %d %d\n", x.a, y, z.a, z.b, w.size(), w[1], e, d.a);
  return 0;
}
