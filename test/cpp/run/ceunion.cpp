// THE EVALUATOR TAKES A UNION BY ITS ACTIVE MEMBER (0.234): a union local of a constexpr function, written and read, and an
// anonymous union in a class built by its constexpr constructors and read by a constexpr member, each in a static
// assertion that a false value fails; and `if consteval''s compile-time branch an immediate function context, where a
// consteval call of a parameter stands for the evaluator
#include <cstdio>
union U { int i; char c; };
constexpr int pick(bool b) { U u{}; if (b) u.i = 7; else u.c = 'x'; return b ? u.i : u.c; }
consteval int twice(int v) { return v * 2; }
constexpr int dual(int v) {
  if consteval { return twice(v); } else { return v + 100; }
}
struct Opt {
  union { int v; char none; };
  bool has;
  constexpr Opt() : none(0), has(false) {}
  constexpr Opt(int x) : v(x), has(true) {}
  constexpr int get() const { return has ? v : -1; }
};
constexpr int optsum() { Opt a; Opt b(42); return a.get() + b.get(); }
int main() {
  constexpr int a = pick(true), b = pick(false);
  static_assert(a == 7 && b == 'x');
  constexpr int c = dual(5);
  static_assert(c == 10);
  static_assert(optsum() == 41);
  Opt o1, o2(42);
  int r = dual(5);
  std::printf("%d %d %d %d %d %d %d\n", a, b, c, r, o1.get(), o2.get(), optsum());
  return 0;
}
