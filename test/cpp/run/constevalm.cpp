// The program's consteval member functions and constructors are immediate ([dcl.constexpr]/13; 0.112): every call is
// folded at compile time, as a free consteval function's has been since 0.99
#include <cstdio>
struct P {
  int x;
  consteval int twice() const { return x * 2; }
  static consteval int sq(int n) { int r = 0; for (int i = 0; i < n; ++i) r += n; return r; }
};
struct C {
  int v;
  int w;
  consteval C(int k) : v(k * 3), w(k + 1) {}
};
constexpr P p{21};
int main() {
  int a = p.twice();
  int b = P::sq(7);
  C c(5);
  static_assert(P::sq(4) == 16);
  std::printf("%d %d %d %d\n", a, b, c.v, c.w);
  return 0;
}
