#include <cstdio>
#include <utility>
// a generic lambda whose written result type names its own parameter pack: SFINAE on the call
static int add(int a, int b) { return a + b; }
static double add(double a, double b, double c) { return a + b + c; }
template <class F, class... A> auto call(F f, A &&... a) -> decltype(f(std::forward<A>(a)...)) { return f(std::forward<A>(a)...); }
int main() {
  auto g = [](auto &&... xs) -> decltype(add(std::forward<decltype(xs)>(xs)...)) { return add(std::forward<decltype(xs)>(xs)...); };
  auto h = [](auto x) -> decltype(x + 1) { return x + 1; };
  std::printf("%d %.1f %d %.1f %d\n", g(2, 3), g(1.0, 2.0, 3.5), h(4), h(1.5), call(g, 5, 6));
  return 0;
}
