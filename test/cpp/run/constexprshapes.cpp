// every shape of a constexpr function folds in a static assertion (0.258): a member and a constructor defined out of the class, a free
// operator, a member template, a virtual member, a lambda, a consteval function, the functions of a namespace
#include <cstdio>
constexpr int a1() { return 1; }
inline constexpr int a3() { return 3; }
static constexpr int a4() { return 4; }
template <class T> constexpr T a5(T t) { return t; }
constexpr auto a7() -> int { return 7; }
consteval int a8() { return 8; }
namespace n { constexpr int a9() { return 9; } template <class T> constexpr T a10(T t) { return t + 1; } }
struct S {
  constexpr S(int k) : v(k) {}
  int v = 0;
  constexpr int m1() const { return v; }
  static constexpr int m3() { return 3; }
  constexpr int m5() const;
  constexpr virtual int m8() const { return 8; }
  constexpr bool operator==(const S &o) const { return v == o.v; }
  template <class U> constexpr U m9(U u) const { return u + v; }
};
constexpr int S::m5() const { return 5; }
struct T2 { int w; constexpr T2(int k); };
constexpr T2::T2(int k) : w(k * 2) {}
constexpr bool operator<(const S &a, const S &b) { return a.v < b.v; }
struct E { int k = 2; };
constexpr int f() { S s(4); auto l = [](int k) { return k * 3; }; E e; return s.m1() + s.m3() + s.m5() + s.m8() + l(2) + T2(5).w + (S(1) < S(2)) + (s == S(4)) + s.m9(1) + e.k; }
static_assert(a1() + a3() + a4() + a5(5) + a7() + a8() + n::a9() + n::a10(9) == 47);
static_assert(f() == 4 + 3 + 5 + 8 + 6 + 10 + 1 + 1 + 5 + 2);
int main() { std::printf("%d %d\n", f(), a1() + a3() + a4() + a5(5) + a7() + n::a9() + n::a10(9)); }
