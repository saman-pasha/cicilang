// std::rel_ops through a using-directive (C++17): !=, >, <= and >= of a class that writes only == and <, at file scope, in a
// block, through a using-declaration of one operator, and inside the program's own template
#include <cstdio>
#include <string>
#include <utility>
struct V {
  int v;
  bool operator==(const V &o) const { return v == o.v; }
  bool operator<(const V &o) const { return v < o.v; }
};
namespace geo {
struct P {
  int x;
  friend bool operator==(const P &a, const P &b) { return a.x == b.x; }
  friend bool operator<(const P &a, const P &b) { return a.x < b.x; }
};
}
int inblock(geo::P a, geo::P b) {
  using namespace std::rel_ops;
  return (a > b) * 100 + (a <= b) * 10 + (a >= b);
}
struct W {
  std::string s;
  bool operator<(const W &o) const { return s < o.s; }
};
using std::rel_ops::operator>;
int onlygt(const W &a, const W &b) { return a > b; }
using namespace std::rel_ops;
template <class T> int ge(const T &a, const T &b) { return a >= b; }
int main() {
  V a{1}, b{2}, c{1};
  std::printf("%d %d %d %d %d %d\n", (int) (a != b), (int) (a != c), (int) (b > a), (int) (a <= c), (int) (a >= b), (int) (b >= a));
  std::printf("%d %d\n", inblock(geo::P{3}, geo::P{2}), inblock(geo::P{2}, geo::P{2}));
  std::printf("%d %d\n", onlygt(W{"pear"}, W{"apple"}), onlygt(W{"apple"}, W{"pear"}));
  std::printf("%d %d %d\n", ge(a, b), ge(b, a), ge(std::string("b"), std::string("a")));
  std::string s = "x", t = "y";
  std::printf("%d %d\n", (int) (s != t), (int) (s > t));
  return 0;
}
