// The backing array of an initializer_list of objects is built element by element in place ([dcl.init.list]/5) and
// destroyed at the end of the full-expression; an aggregate's prvalue is built in its place; a braced argument to a
// by-value parameter is the parameter; a lambda is a braced list's item; a local initializer_list and `auto x = {a, b}`
// hold their arrays as long as they live (0.206).
#include <cstdio>
#include <functional>
#include <initializer_list>
#include <list>
#include <map>
#include <set>
#include <string>
#include <vector>
struct Cnt {
  static int live, made;
  int v;
  Cnt(int x) : v(x) { ++live; ++made; }
  Cnt(const Cnt &o) : v(o.v) { ++live; ++made; }
  ~Cnt() { --live; }
};
int Cnt::live = 0, Cnt::made = 0;
int sum(std::vector<Cnt> v) { int s = 0; for (const Cnt &c : v) s += c.v; return s; }
int total(std::vector<int> v) { int s = 0; for (int x : v) s += x; return s; }
struct Node {
  int v;
  std::vector<Node> kids;
  std::list<Node> more;
};
struct Leaf {
  int v;
  std::list<int> more;
};
int main() {
  std::vector<std::list<int>> vl{{1, 2}, {3}};
  std::printf("lists %zu %zu %d %d\n", vl[0].size(), vl[1].size(), vl[0].back(), vl[1].front());
  std::vector<std::set<int>> vs{{4, 5}, {6}};
  std::printf("sets %zu %zu %d\n", vs[0].size(), vs[1].size(), *vs[0].rbegin());
  std::vector<std::map<int, int>> vm{{{1, 10}}, {{2, 20}, {3, 30}}};
  std::printf("maps %zu %zu %d\n", vm[0].size(), vm[1].size(), vm[1].at(3));
  std::vector<std::list<int>> vp{std::list<int>{8, 9}};
  std::printf("prvalue %zu %d\n", vp[0].size(), vp[0].back());
  Leaf la[1] = {Leaf{2, {}}};
  std::printf("leaf array %zu %d\n", la[0].more.size(), (int) la[0].more.empty());
  std::vector<Leaf> lv{Leaf{3, {}}};
  std::printf("leaf vector %zu %zu\n", lv.size(), lv[0].more.size());
  Node na[1] = {Node{2, {}, {}}};
  std::printf("node array %zu %zu\n", na[0].more.size(), na[0].kids.size());
  std::vector<Node> nv{Node{2, {}, {}}};
  std::printf("node vector %zu %zu\n", nv.size(), nv[0].more.size());
  { std::vector<Cnt> v{Cnt(1), Cnt(2), Cnt(3)}; std::printf("in %d %zu %d\n", Cnt::live, v.size(), Cnt::made); }
  std::printf("after %d\n", Cnt::live);
  { std::vector<Cnt> w{4, 5}; std::printf("conv %d %d\n", Cnt::live, w[1].v); }
  std::printf("after2 %d\n", Cnt::live);
  Cnt a(6);
  { std::vector<Cnt> x{a, a}; std::printf("lvalue %d %d\n", Cnt::live, x[0].v + x[1].v); }
  std::printf("after3 %d\n", Cnt::live);
  bool c = Cnt::live > 100;
  int s = c ? sum({Cnt(7), Cnt(8)}) : sum({Cnt(9)});
  std::printf("cond %d %d\n", s, Cnt::live);
  int t = sum({Cnt(10), Cnt(11)});
  std::printf("call %d %d\n", t, Cnt::live);
  std::printf("by value %d\n", total({5, 6}) + total({7}));
  int k = 7;
  std::vector<std::function<int()>> vf{[] { return 1; }, [k] { return k; }};
  std::printf("functions %d %d\n", vf[0](), vf[1]());
  std::function<int()> f1{[] { return 3; }};
  std::printf("one %d\n", f1());
  std::initializer_list<int> il{1, 2, 3};
  auto al = {4, 5};
  int u = 0;
  for (int x : il) u += x;
  for (int x : al) u += x * 10;
  std::printf("int lists %zu %zu %d\n", il.size(), al.size(), u);
  {
    std::initializer_list<Cnt> ic{Cnt(1), Cnt(2), 3};
    int w = 0;
    for (const Cnt &e : ic) w += e.v;
    std::printf("object list %d %d\n", w, Cnt::live);
    auto ac = {Cnt(4), Cnt(5)};
    std::printf("auto list %zu %d\n", ac.size(), Cnt::live);
    std::initializer_list<std::string> ls{"a", "bb"};
    std::printf("strings %zu %zu\n", ls.size(), ls.begin()[1].size());
  }
  std::printf("end %d\n", Cnt::live);
}
