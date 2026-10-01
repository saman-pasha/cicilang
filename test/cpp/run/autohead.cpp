// A function template with an `auto' parameter beside its written head ([dcl.fct]/22): the invented template
// parameter follows the written ones, as libc++ 18's `__parse_arg_id(_Iterator, _Iterator, auto &)' writes it.
#include <cstdio>
template <class I> int f(I a, auto &b) { return (int) sizeof(a) * 10 + (int) sizeof(b); }
template <class I> requires (sizeof(I) <= 4) int g(I a, const auto &b, auto c) { return (int) a + (int) b * 10 + (int) c * 100; }
int main() {
  double d = 1;
  char c = 2;
  std::printf("%d %d %d\n", f(1, d), f(c, c), g(3, 4.0, 5L));
  return 0;
}
