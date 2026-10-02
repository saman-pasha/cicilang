// A member whose requires-clause is unmet is not instantiated ([temp.inst]/11): Box<S>'s `auto twice()' would
// multiply a struct, and its result is not deduced.
#include <concepts>
#include <cstdio>

template <class T> struct Box {
  T t;
  auto twice() const requires std::integral<T> { return t * 2; }
  int get() const { return 1; }
};
struct S { int v; };

int main() {
  Box<int> a{4};
  Box<S> b{{5}};
  std::printf("%d %d\n", a.twice(), b.get());
  return 0;
}
