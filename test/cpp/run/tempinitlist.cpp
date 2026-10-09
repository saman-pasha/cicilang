// braced temporaries and the initializer_list constructor (0.117): `T{a, b}' of a class WITH one takes the list through it FIRST
// ([over.match.list]/1) -- `std::vector<int>{5}' is one element, `std::vector<std::string>{"a", "b"}' two strings, never the
// (count, value) or (first, last) constructors the items would fit as arguments -- as an argument, as `return {...}', as a braced
// argument to a class parameter, as a nested item, and in a method (its members named bare); a copy `T{v}' stays the copy
#include <cstdio>
#include <map>
#include <set>
#include <string>
#include <vector>
int total(const std::vector<std::string> &v) { int n = 0; for (const auto &s : v) n += (int)s.size(); return n * 10 + (int)v.size(); }
std::vector<std::string> pair_of() { return {"left", "right"}; }
std::vector<int> three() { return {7, 8, 9}; }
struct Box {
  int n_ = 3, m_ = 4;
  int sum() const { int s = 0; for (int x : std::vector<int>{n_, m_, n_ + m_}) s += x; return s; }
};
int main() {
  std::printf("%d\n", total(std::vector<std::string>{"a", "bb"}));
  std::printf("%zu %zu\n", std::vector<int>{5}.size(), std::vector<int>(5).size());
  std::printf("%d\n", total(std::vector<std::string>({"x", "y", "zz"})));
  std::vector<std::string> p = pair_of();
  std::printf("%zu %s %s\n", p.size(), p[0].c_str(), p[1].c_str());
  std::printf("%zu %d\n", three().size(), three()[2]);
  std::printf("%d\n", total({"q", "rs", "tuv"}));
  std::vector<std::vector<int>> vv = {{1, 2}, {3}, {4, 5, 6}};
  std::printf("%zu %zu %zu %zu\n", vv.size(), vv[0].size(), vv[1].size(), vv[2].size());
  for (int x : std::vector<int>{4, 5, 6}) std::printf("%d ", x);
  for (int x : std::vector<int>(2, 9)) std::printf("%d ", x);
  for (const auto &s : std::vector<std::string>{"u", "v"}) std::printf("%s ", s.c_str());
  std::printf("\n");
  std::vector<int> a{1, 2};
  std::vector<int> b{a};
  std::printf("%zu %zu\n", a.size(), b.size());
  std::printf("%zu %zu\n", std::set<int>{3, 1, 2, 3}.size(), std::map<std::string, int>{{"a", 1}, {"b", 2}}.size());
  Box box; std::printf("%d\n", box.sum());
  return 0;
}
