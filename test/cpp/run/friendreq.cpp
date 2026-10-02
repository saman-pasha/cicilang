// A hidden friend whose requires-clause is unmet is no candidate and is not instantiated ([temp.inst]/11):
// W<NoCmp>'s operator<=> would refuse over a class without <=>; W<int>'s is used.
#include <compare>
#include <cstdio>

struct NoCmp { int v; };
inline int val(const NoCmp &n) { return n.v; }
inline int val(int i) { return i; }

template <class T> struct W {
  T t;
  friend auto operator<=>(const W &a, const W &b)
    requires requires (T x) { x <=> x; }
  { return a.t <=> b.t; }
  friend bool operator==(const W &a, const W &b) { return val(a.t) == val(b.t); }
};

int main() {
  W<NoCmp> a{{3}}, b{{3}};
  W<int> c{1}, d{2};
  std::printf("%d %d %d\n", a == b ? 1 : 0, (c <=> d) < 0 ? 1 : 0, c == d ? 1 : 0);
  return 0;
}
