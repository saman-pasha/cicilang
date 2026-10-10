// A prvalue that initializes an object of its class is constructed IN that object (C++17, [class.copy.elision]/1),
// and a returned local moves into the caller's result: a class that holds its own address (a map's end node, a list's
// sentinel, a std::function's small buffer) must not be copied bitwise.
#include <cstdio>
#include <functional>
#include <list>
#include <map>

struct S {
  int v;
  S(int x) : v(x) { std::printf("ctor %d\n", v); }
  S(const S &o) : v(o.v) { std::printf("copy %d\n", v); }
  S(S &&o) : v(o.v) { std::printf("move %d\n", v); }
};
template <class T> struct Wrap { T t; };

int twice(int x) { return 2 * x; }
std::map<int, int> build() { std::map<int, int> m; m[1] = 2; m[3] = 4; return m; }
std::map<int, int> mk() { return std::map<int, int>{{1, 2}, {7, 8}}; }
std::list<int> lst() { return std::list<int>{1, 2, 3}; }
std::list<int> lst2() { std::list<int> l; l.push_back(4); l.push_back(5); return l; }
std::map<int, int> forward() { return build(); }

int main() {
  std::function<int(int)> f = std::function<int(int)>(twice);
  std::printf("%d\n", f(21));
  std::map<int, int> m = build();
  m[5] = 6;
  for (auto &kv : m) std::printf("%d=%d ", kv.first, kv.second);
  std::printf("\n");
  auto n = build();
  n.erase(1);
  std::printf("%d\n", (int) n.size());
  std::map<int, int> k = mk();
  k[9] = 10;
  for (auto &kv : k) std::printf("%d=%d ", kv.first, kv.second);
  std::printf("\n");
  std::list<int> l = lst();
  l.push_back(4);
  for (int x : l) std::printf("%d ", x);
  std::printf("\n");
  std::list<int> l2 = lst2();
  l2.push_front(3);
  for (int x : l2) std::printf("%d ", x);
  std::printf("\n");
  std::map<int, int> fw = forward();
  fw[2] = 3;
  for (auto &kv : fw) std::printf("%d=%d ", kv.first, kv.second);
  std::printf("\n");
  Wrap<std::list<int>> w{std::list<int>{7, 8}};
  w.t.push_back(9);
  for (int x : w.t) std::printf("%d ", x);
  std::printf("\n");
  Wrap<S> ws{S(9)};
  std::printf("%d\n", ws.t.v);
  return 0;
}
