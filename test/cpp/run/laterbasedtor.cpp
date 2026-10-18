// a class with no destructor of its own over a later base that has one: its implicit destructor destroys that base -- a local, a
// member, an array, a delete, a delete through a base whose destructor is virtual -- and std::tuple destroys every element
#include <cstdio>
#include <string>
#include <tuple>
#include <utility>
struct P { int p = 1; };
struct Q { int q = 2; ~Q() { std::printf("~Q %d\n", q); } };
struct T : P, Q { int t = 3; };
struct H { T t; };
struct V { int v = 0; virtual int f() { return 1; } };
struct W { std::string s = "w"; virtual ~W() { std::printf("~W %s\n", s.c_str()); } };
struct X : V, W { int f() override { return 2; } };
struct Y : X { ~Y() { std::printf("~Y\n"); } };
static int live = 0;
struct C { int k; C(int k) : k(k) { live++; } C(const C &o) : k(o.k) { live++; } C(C &&o) : k(o.k) { live++; } ~C() { live--; } };
int main() {
  { T t; t.q = 7; std::printf("t %d %d %d\n", t.p, t.q, t.t); }
  { H h; h.t.q = 8; }
  { T a[2]; a[0].q = 9; a[1].q = 10; }
  T *pt = new T; pt->q = 11; delete pt;
  X *px = new Y; std::printf("f %d\n", px->f()); delete px;
  W *pw = new Y; delete pw;
  {
    std::tuple<int, std::string, std::string> tp(1, std::string(40, 'a'), std::string(40, 'b'));
    auto tp2 = tp;
    auto tp3 = std::move(tp2);
    std::printf("%d %zu %zu %zu\n", std::get<0>(tp3), std::get<1>(tp3).size(), std::get<2>(tp).size(), std::get<2>(tp2).size());
    tp2 = tp3;
    std::get<2>(tp2) += "c";
    std::printf("%zu %zu\n", std::get<2>(tp2).size(), std::get<2>(tp3).size());
  }
  {
    std::tuple<int, C, C> tc(1, C(2), C(3));
    auto tc2 = tc;
    std::printf("live %d\n", live);
  }
  std::printf("live %d\n", live);
  return 0;
}
