// A local's constructor call converts its arguments as a call does (0.112): a by-value parameter of class type
// takes another type through the class's converting constructor -- a constrained template one, ref_view's shape
#include <cstdio>
#include <type_traits>
#include <vector>
struct Len { int n; template <class T> requires (!std::is_same_v<T, Len>) Len(T &t) : n((int) t.size()) {} };
struct Box { int v; Box(int x) : v(x * 10) {} };
template <class V> struct H { V b; int m; H(V x, int y) : b(x), m(y) {} };
struct G { Box q; G(Box b) : q(b) {} };
int main() {
  std::vector<int> v{1, 2, 3, 4};
  H<Len> h(v, 2);
  G g(5);
  std::printf("%d %d %d\n", h.b.n, h.m, g.q.v);
  return 0;
}
