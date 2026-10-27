// What a library object may hold and hand on (0.216): the caller's objects, by-value captures, a literal's view, a copy
// of a local array, a parameter's iterator, a deleter found in place, borrows of locals used in their scope, stores through
// references that stay in the function, a const lookup, contents replaced after the old ones died, a view assigned a string
#include <algorithm>
#include <cstdio>
#include <functional>
#include <iterator>
#include <memory>
#include <set>
#include <string>
#include <string_view>
#include <vector>
std::vector<int *> both(int &a, int &b) { std::vector<int *> v; v.push_back(&a); v.push_back(&b); return v; }
std::vector<int *> keep(int *p) { std::vector<int *> v{p}; auto &r = v; r.push_back(v[0]); return v; }
std::function<int()> twice(int x) { return [x] { return x * 2; }; }
std::string_view lit() { return std::string_view("literal"); }
std::string copied() { char buf[6] = "local"; return std::string(buf); }
std::vector<int>::iterator second(std::vector<int> &v) { return v.begin() + 1; }
struct Del { int calls = 0; void operator()(int *) { ++calls; } };
static int kept = 3;
int deleter() { std::shared_ptr<int> sp(&kept, Del()); Del *d = std::get_deleter<Del>(sp); return d ? 1 : 0; }
int local() { int x = 4, y = 5; std::vector<int *> v{&x, &y}; std::vector<int *> *p = &v; p->push_back(&x); int s = 0; for (int *q : v) s += *q; return s; }
int rows() { int b = 2; std::vector<std::vector<int *>> g(2); for (auto &row : g) row.push_back(&b); int s = 0; for (auto &row : g) for (int *q : row) s += *q; return s; }
bool has(const std::set<int *> &s) { int k = 3; return s.count(&k) > 0; }
int copy(int *a) { std::vector<int *> src{a}, dst; std::copy(src.begin(), src.end(), std::back_inserter(dst)); return (int) dst.size(); }
int byval(std::vector<int *> v) { int x = 4; v.push_back(&x); return (int) v.size(); }
int replaced() {
  std::string_view sv;
  { std::string a = "a string long enough to live on the heap"; sv = a; }
  std::string b = "second";
  sv = b;
  std::vector<int *> v;
  int total = (int) sv.size();
  for (int i = 0; i < 3; ++i) { int x = i; v.clear(); v.push_back(&x); total += *v[0]; }
  std::vector<int *> w;
  { int y = 5; w.push_back(&y); total += *w[0]; }
  int z = 7;
  w = {&z};
  return total + *w[0];
}
int main() {
  int a = 1, b = 2;
  std::vector<int> w{10, 20, 30};
  std::set<int *> s{&a};
  std::printf("%zu %zu %d %s %s %d %d\n", both(a, b).size(), keep(&a).size(), twice(21)(), std::string(lit()).c_str(), copied().c_str(), *second(w), deleter());
  std::printf("%d %d %d %d %d %d\n", local(), rows(), has(s) ? 1 : 0, copy(&a), byval({}), replaced());
  return 0;
}
