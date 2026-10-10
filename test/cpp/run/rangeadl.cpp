// A range-for over a class with no member begin and end: the free ones of its namespace, found by argument-dependent
// lookup -- two namespaces with a `begin' and an `end' each.
#include <cstdio>
namespace geo {
struct Path { int pts[4]; int n; };
struct It {
  const Path &p;
  int i;
  int operator*() const { return p.pts[i]; }
  It &operator++() { ++i; return *this; }
  bool operator!=(const It &o) const { return i != o.i; }
};
It begin(const Path &q) { return It{q, 0}; }
It end(const Path &q) { return It{q, q.n}; }
}
namespace shop {
struct Basket { int items[3]; };
struct Cursor {
  const Basket &b;
  int k;
  int operator*() const { return b.items[k] * 10; }
  Cursor &operator++() { ++k; return *this; }
  bool operator!=(const Cursor &o) const { return k != o.k; }
};
Cursor begin(const Basket &b) { return Cursor{b, 0}; }
Cursor end(const Basket &b) { return Cursor{b, 3}; }
}
int main() {
  geo::Path p{{3, 1, 4, 1}, 3};
  int sum = 0;
  for (int v : p) sum += v;
  for (const int &v : p) std::printf("%d ", v);
  std::printf("| %d\n", sum);
  shop::Basket b{{5, 6, 7}};
  int t = 0;
  for (int v : b) t += v;
  std::printf("%d\n", t);
  return 0;
}
