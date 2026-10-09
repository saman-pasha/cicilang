#include <cstdio>
#include <functional>
#include <list>
#include <map>
#include <string>
struct S {
  int v;
  S(int x) : v(x) { std::printf("ctor %d\n", v); }
  S(S &&o) : v(o.v) { std::printf("move %d\n", v); }
  S(const S &) = delete;
  ~S() { std::printf("dtor %d\n", v); }
};
struct H { S m_; H() : m_(S(5)) {} };
struct K { S a_; S b_; K(int x) : a_(S(x)), b_(S(x + 1)) {} };
static int twice(int x) { return 2 * x; }
struct F { std::function<int(int)> f_; F() : f_(std::function<int(int)>(twice)) {} };
struct L { std::list<int> l_; L() : l_(std::list<int>{1, 2, 3}) {} };
struct M { std::map<int, int> m_; M() : m_(std::map<int, int>{{1, 2}}) {} };
struct T { std::string s_; T() : s_(std::string("hello")) {} };
int main() {
  H h; std::printf("%d\n", h.m_.v);
  K k(7); std::printf("%d %d\n", k.a_.v, k.b_.v);
  F f; std::printf("%d\n", f.f_(21));
  L l; l.l_.push_back(4); for (int x : l.l_) std::printf("%d ", x); std::printf("\n");
  M m; m.m_[3] = 4; for (auto &kv : m.m_) std::printf("%d=%d ", kv.first, kv.second); std::printf("\n");
  T t; std::printf("%s\n", t.s_.c_str());
  return 0;
}
