#include <cstdio>
#include <string>
#include <utility>
#include <vector>
// a member initializer's designated braced list ([class.base.init]/7, [dcl.init.aggr]/3.1): the aggregate member built
// from its designators, the members it skips from their defaults, in a class and in a class template, as libc++ 21's
// flat_map writes `__containers_{.keys = std::move(__key_cont), .values = std::move(__mapped_cont)}'
struct Pair {
  std::vector<int> keys;
  std::vector<std::string> values;
};
struct Plain {
  int a;
  int b = 7;
  int c;
};
struct Holder {
  Pair p;
  Plain q;
  Holder(std::vector<int> k, std::vector<std::string> v) : p{.keys = std::move(k), .values = std::move(v)}, q{.a = 1, .c = 3} {}
};
template <class K, class V>
struct Map {
  struct containers {
    std::vector<K> keys;
    std::vector<V> values;
  };
  containers c_;
  Map(std::vector<K> k, std::vector<V> v) : c_{.keys = std::move(k), .values = std::move(v)} {}
  std::size_t size() const { return c_.keys.size(); }
};
int main() {
  Holder h({1, 2, 3}, {"one", "two", "three"});
  std::printf("%zu %zu %s %d %d %d\n", h.p.keys.size(), h.p.values.size(), h.p.values[1].c_str(), h.q.a, h.q.b, h.q.c);
  Map<int, std::string> m({4, 5}, {"four", "five"});
  std::printf("%zu %s\n", m.size(), m.c_.values[0].c_str());
  return 0;
}
