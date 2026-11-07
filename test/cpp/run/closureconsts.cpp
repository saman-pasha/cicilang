// a lambda's body and a local class's member read their function's constants with no capture (0.258), an instance's body reads
// none of its caller's, and a reference bound to an object the evaluation does not see is never read
#include <cstdio>
struct P { int x, y; constexpr P(int a, int b) : x(a), y(b) {} };
constexpr int n = 1;
template <class T> int g(T) { int a[n]; return (int)sizeof(a) / (int)sizeof(int) + n; }
int f0() { const int n = 5; return g(0) + n; }
int f1() {
  constexpr int n = 3;
  const int m = 4;
  constexpr P p(5, 6);
  auto l = [] { return n * 2 + m + p.x; };
  static_assert(l() == 15);
  struct L { static constexpr int g() { return n + m + p.y; } };
  static_assert(L::g() == 13);
  return l() + L::g();
}
int f2() { constexpr int k = 3; auto l = [](auto x) { return x * k; }; return l(2); }
int f3() { constexpr int k = 4; auto l = [k](int x) { return x + k; }; auto m = [=](int x) { return x - k; }; return l(1) + m(10); }
constexpr int K = 1;
constexpr int gk3(const int &) { return K; }
int f4() { int K = 5; int x = 2; static_assert(gk3(x) == 1); const int z = gk3(x); return K + x + z; }
int main() { std::printf("%d %d %d %d %d\n", f0(), f1(), f2(), f3(), f4()); }
