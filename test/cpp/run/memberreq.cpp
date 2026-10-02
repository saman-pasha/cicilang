// a member whose trailing requires-clause is unmet is no candidate and is not instantiated ([temp.inst]/11): view<W>'s empty() and size() name members W has not
#include <cstdio>
struct V { int n; bool empty() const { return n == 0; } int size() const { return n; } };
struct W { int n; };
template <class R> struct view {
  R r_;
  view(R r) : r_(r) {}
  bool empty() const requires requires { r_.empty(); } { return r_.empty(); }
  int size() const requires requires { r_.size(); } { return r_.size(); }
  int get() const { return 7; }
};
int main() {
  V v{3}; W w{5};
  view<V> a(v); view<W> b(w);
  std::printf("%d %d %d\n", (int) a.empty(), a.size(), b.get());
  return 0;
}
