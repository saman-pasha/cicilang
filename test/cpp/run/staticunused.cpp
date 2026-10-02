// A static member whose items do not fold to constants -- immediately invoked lambdas -- is declared and not defined;
// unused, it costs nothing. libc++ 18's basic_format_string holds `__handles_' so, for the consteval check this
// compiler drops.
#include <cstdio>
struct H { int (*f)(int); constexpr H() : f([](int x) { return x + 1; }) {} };
template <class T, unsigned N> struct Arr { T e_[N]; };
template <class... As> struct S {
  static constexpr Arr<H, sizeof...(As)> handles_{[] { using T = As; H h; (void) sizeof(T); return h; }()...};
  static constexpr Arr<int, sizeof...(As)> sizes_{(int) sizeof(As)...};
  static int sum() { int s = 0; for (unsigned i = 0; i < sizeof...(As); i++) s += sizes_.e_[i]; return s; }
};
int main() { std::printf("%d\n", S<int, double, char>::sum()); return 0; }
