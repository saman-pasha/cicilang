// libc++'s take_while_view sentinel, on the program's own classes: a member class template defined out of its
// class template, a friend of its other specialization, a constructor from that specialization under a
// requires-clause, and a hidden friend operator== against an iterator
#include <cstdio>
template <class T> struct V {
  T b, e;
  template <bool C> class S;
  S<true> end() const { return S<true>(e, 3); }
  S<false> end2() { return S<false>(e, 4); }
};
template <class T> template <bool C> class V<T>::S {
  T end_ = 0;
  int lim_ = 0;
  friend class S<!C>;
public:
  S() = default;
  S(T e, int l) : end_(e), lim_(l) {}
  S(S<!C> s) requires C : end_(s.end_), lim_(s.lim_ + 100) {}
  int lim() const { return lim_; }
  friend bool operator==(const T &x, const S &y) { return x == y.end_ || x >= y.lim_; }
};
int main() {
  V<int> v{0, 5};
  int n = 0; for (int i = v.b; !(i == v.end()); ++i) n++;
  int m = 0; for (int i = v.b; !(i == v.end2()); ++i) m++;
  V<int>::S<true> t = v.end2();
  std::printf("%d %d %d\n", n, m, t.lim());
  return 0;
}
