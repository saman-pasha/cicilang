// A defaulted default constructor whose requires-clause fails is no default constructor (0.112): the member
// with no default constructor is never default-constructed, and the class keeps its other constructors
#include <concepts>
#include <cstdio>
struct NoDef { int n; NoDef(int x) : n(x) {} };
template <class V> struct H {
  V b = V();
  int k = 7;
  H() requires std::default_initializable<V> = default;
  H(V x) : b(x), k(1) {}
};
int main() {
  H<NoDef> a(NoDef(3));
  H<int> c;
  H<int> d(5);
  std::printf("%d %d %d %d %d %d\n", a.b.n, a.k, c.b, c.k, d.b, d.k);
  std::printf("%d %d\n", (int) std::default_initializable<H<NoDef>>, (int) std::default_initializable<H<int>>);
  return 0;
}
