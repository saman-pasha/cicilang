// A friend template of a member class template compares an iterator with a sentinel (C++20): its parameters name
// the sibling member template and the class by their short names, its requires-clause a class typedef, as libc++'s
// `elements_view<_View, _Np>::__sentinel' writes `operator==(const __iterator<_OtherConst> &, const __sentinel &)',
// its body calling the class's static member template bare
#include <cstdio>
template <class V> struct View {
  template <bool Const> struct Iter {
    int i;
    friend bool operator==(const Iter &a, const Iter &b) { return a.i == b.i; }
  };
  template <bool Const> struct Sent {
    using Base = V;
    int end;
    template <bool A> static int cur(const Iter<A> &i) { return i.i; }
    template <bool OtherConst>
      requires(sizeof(Base) > 0)
    friend bool operator==(const Iter<OtherConst> &i, const Sent &s) { return cur(i) == s.end; }
  };
  V v;
  Iter<true> begin() const { return {0}; }
  Sent<true> end() const { return {v.n}; }
};
struct Arr { int data[3]; int n; };
int main() {
  View<Arr> w{{{4, 5, 6}, 3}};
  int s = 0;
  for (auto it = w.begin(); !(it == w.end()); it.i++) s += w.v.data[it.i];
  std::printf("%d\n", s);
  return 0;
}
