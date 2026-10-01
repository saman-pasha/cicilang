// Class template argument deduction through a constructor that names the class by its injected name: in the guide
// the name means the class over its own parameters ([temp.local]/1). libc++ 18's basic_format_context deduces _CharT
// from `basic_format_args<basic_format_context>' so.
#include <cstdio>
template <class Ctx> struct Args { int n; };
template <class It, class Ch> struct Ctx {
  It it;
  Args<Ctx> args;
  Ctx(It i, Args<Ctx> a) : it(i), args(a) {}
  int total() const { return (int) it + args.n + (int) sizeof(Ch); }
};
template <class It, class Ch> Ctx<It, Ch> make(It i, Args<Ctx<It, Ch>> a) { return Ctx(i, a); }
int main() {
  Args<Ctx<long, char>> a{5};
  Ctx<long, char> c = make(10L, a);
  Args<Ctx<int, double>> b{7};
  auto d = Ctx(3, b);
  std::printf("%d %d\n", c.total(), d.total());
  return 0;
}
