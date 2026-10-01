// an explicit constructor makes no implicit conversion ([class.conv.ctor], [meta.rel]): the trait, and the overload
// it steers -- a function taking E is no candidate for an int, one taking I is
#include <cstdio>
#include <type_traits>
struct E { int v; explicit E(int x) : v(x) {} };
struct I { int v; I(int x) : v(x) {} };
int pick(E e) { return e.v * 10; }
int pick(long n) { return (int) n + 1; }
int take(I i) { return i.v * 100; }
int main() {
  std::printf("%d %d %d %d\n", (int) std::is_convertible_v<int, E>, (int) std::is_convertible_v<int, I>,
              (int) std::is_constructible_v<E, int>, (int) std::is_constructible_v<I, int>);
  std::printf("%d %d %d\n", pick(4), pick(E(4)), take(5));
  return 0;
}
