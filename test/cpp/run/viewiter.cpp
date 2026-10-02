// transform_view's iterator on the program's own classes: a member class template defined out of its class
// template, a friend of its other specialization by the qualified name, the parent through a conditional alias,
// a converting constructor under a requires-clause, hidden friend comparisons
#include <cstdio>
template <bool C, class T> struct cond_const { using type = T; };
template <class T> struct cond_const<true, T> { using type = const T; };
template <bool C, class T> using maybe_const = typename cond_const<C, T>::type;

template <class F> struct TV {
  template <bool> class It;
  int d[4] = {1, 2, 3, 4}; F f_;
  TV(F f) : f_(f) {}
  It<false> begin() { return It<false>(*this, 0); }
  It<false> end() { return It<false>(*this, 4); }
  It<true> begin() const { return It<true>(*this, 0); }
};
template <class F> template <bool Const> class TV<F>::It {
  using Parent = maybe_const<Const, TV>;
  Parent &parent_;
  template <bool> friend class TV::It;
public:
  int i_ = 0;
  It(Parent &p, int i) : parent_(p), i_(i) {}
  It(It<!Const> o) requires Const : parent_(o.parent_), i_(o.i_) {}
  int operator*() const { return parent_.f_(parent_.d[i_]); }
  It &operator++() { ++i_; return *this; }
  friend bool operator==(const It &a, const It &b) { return a.i_ == b.i_; }
};
int main() {
  auto sq = [](int n) { return n * n; };
  TV<decltype(sq)> t(sq);
  int s = 0; for (auto it = t.begin(); !(it == t.end()); ++it) s += *it;
  const TV<decltype(sq)> &ct = t; auto c0 = ct.begin();
  TV<decltype(sq)>::It<true> c1 = t.begin();
  std::printf("%d %d %d\n", s, *c0, *c1);
  return 0;
}
