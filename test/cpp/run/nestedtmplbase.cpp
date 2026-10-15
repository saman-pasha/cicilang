// A member class template whose primary has an EMPTY body and whose partial specialization is constrained, used as
// the base of a nested class template (lazy_split_view's `__outer_iterator_category' under `__outer_iterator').
#include <cstdio>
#include <concepts>
template <class V>
struct Outer {
  template <class>
  struct Cat {};
  template <std::integral T>
  struct Cat<T> {
    using kind = int;
  };
  template <bool B>
  struct It : Cat<V> {
    int v = B ? 1 : 2;
  };
  auto begin() { return It<sizeof(V) == 4>{}; }
};
int main() {
  Outer<int> o;
  Outer<double> d;
  typename Outer<int>::template It<true>::kind k = 5;
  std::printf("%d %d %d\n", o.begin().v, d.begin().v, k);
  return 0;
}
