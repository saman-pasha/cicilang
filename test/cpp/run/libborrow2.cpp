// What the safe part lets through at the library's boundary (0.217): an iterator and a pointer into a vector of pointers
// used while it lives, stores through a range-for's references, a member of the program's class storing its parameter
// and the object used while the local lives, a member storing a copy, a sort with a comparator over a local by
// reference, a find of a local's address, a swap and a fill and a copy among locals, a parameter's borrows returned
#include <algorithm>
#include <cstdio>
#include <iterator>
#include <utility>
#include <vector>
struct Registry { std::vector<int *> items; std::vector<int> values; void add(int *w) { items.push_back(w); } void keep(int *w) { values.push_back(*w); } };
Registry copies() { int w = 7; Registry r; r.keep(&w); return r; }
std::vector<int *> sorted(std::vector<int *> v) { int bias = 0; std::sort(v.begin(), v.end(), [&](int *a, int *b) { return *a + bias < *b + bias; }); int k = 0; (void) std::find(v.begin(), v.end(), &k); return v; }
std::vector<int *> theirs(int *p, int *q) { std::vector<int *> a{p}, b; std::swap(a, b); std::vector<int *> c(1); std::fill(c.begin(), c.end(), q); std::copy(c.begin(), c.end(), std::back_inserter(b)); return b; }
int main() {
  int x = 1, y = 2;
  std::vector<int *> v{&x, &y};
  auto it = v.begin();
  std::vector<int *> *pv = &v;
  std::vector<std::vector<int *>> g(2);
  for (auto &row : g) row.push_back(&x);
  int s = 0;
  for (auto &row : g) for (int *p : row) s += *p;
  Registry r;
  r.add(&x);
  r.add(&y);
  int t = 0;
  for (int *p : r.items) t += *p;
  std::vector<int *> w = sorted(v);
  std::vector<int *> u = theirs(&x, &y);
  std::printf("%d %zu %d %d %zu %d %d %zu %d %d\n", **it, pv->size(), s, t, copies().values.size(), *w[0], *w[1], u.size(), *u[0], *u[1]);
  return 0;
}
