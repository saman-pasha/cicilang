// A STATIC FED BY A TEMPLATE VALUE ARGUMENT THIS COMPILER DOES NOT FOLD (0.160): a constexpr function over a double keys
// the instance by its spelling, and the static is a linkonce zero that the unit's initialization sets before main
#include <cstdio>
constexpr int half(double x) { return (int) (x * 2.5); }
template <int N> struct S { static const int v = N * 2; static int get() { return v + 1; } };
int main() {
  std::printf("%d %d\n", S<half(4.0)>::v, S<half(4.0)>::get());
  return 0;
}
