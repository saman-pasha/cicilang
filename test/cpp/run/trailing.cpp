// a free function's trailing return type (0.110): a prototype's and a definition's
#include <cstdio>
auto add(int a, int b) -> long;
auto twice(double x) -> double { return x * 2; }
auto half(int x) -> double { return x / 2; }
template <class T> auto sq(T x) -> decltype(x * x) { return x * x; }
auto pick(bool b) -> const char * { return b ? "yes" : "no"; }
struct P { int v; auto get() const -> int { return v; } };
int main() {
  long r = add(2, 3);
  printf("%ld %g %g %d %s %d %d\n", r, twice(1.5), half(5), sq(7), pick(true), P{4}.get(), (int) sizeof(add(1, 2)));
  return 0;
}
auto add(int a, int b) -> long { return (long) a + b; }
