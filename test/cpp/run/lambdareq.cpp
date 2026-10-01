// A lambda's requires-clause is its operator()'s constraint ([expr.prim.lambda.closure]/3): checked where the call is
// resolved, so a detection sees it
#include <cstdio>
template <class T> concept Small = sizeof(T) <= 4;
template <class T> concept Wide = sizeof(T) >= 8;
template <class F, class A> constexpr bool callable = requires(F f, A a) { f(a); };
int main() {
  auto twice = []<class T> requires Small<T> (T x) { return x * 2; };
  auto half = [](auto x) requires Wide<decltype(x)> { return x / 2; };
  std::printf("%d %d\n", twice(21), (int) half(9.0));
  std::printf("%d %d %d %d\n", (int) callable<decltype(twice), int>, (int) callable<decltype(twice), double>,
              (int) callable<decltype(half), double>, (int) callable<decltype(half), char>);
  return 0;
}
