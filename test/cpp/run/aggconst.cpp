// An aggregate's designated list is positional over its members, and a member the list does not give takes its
// default member initializer ([dcl.init.aggr]/3.1, /5.1) -- in a global constant, a local and a nested member alike.
// libc++ 18's `inline constexpr __fields __fields_integral{.__sign_ = true, ...}' is a list of bitfields so.
#include <cstdio>
#include <cstdint>
struct F { uint16_t a_ : 1 {false}; uint16_t b_ : 1 {false}; uint16_t c_ : 1 {true}; int n = 7; };
struct Outer { F f; int k{3}; char s[3] = {'x'}; };
inline constexpr F fa{.a_ = true};
constexpr F fb{.b_ = true, .n = 9};
F fc{.c_ = false};
constexpr Outer oa{};
constexpr Outer ob{.k = 5};
int main() {
  F l{.b_ = true};
  Outer lo{.k = 8};
  std::printf("%d %d %d %d\n", fa.a_, fa.b_, fa.c_, fa.n);
  std::printf("%d %d %d %d\n", fb.a_, fb.b_, fb.c_, fb.n);
  std::printf("%d %d %d %d\n", fc.a_, fc.b_, fc.c_, fc.n);
  std::printf("%d %d %d %c\n", oa.f.c_, oa.f.n, oa.k, oa.s[0]);
  std::printf("%d %d %d\n", ob.f.c_, ob.k, (int) ob.s[1]);
  std::printf("%d %d %d %d\n", l.a_, l.b_, l.c_, l.n);
  std::printf("%d %d %c\n", lo.f.c_, lo.k, lo.s[0]);
  return 0;
}
