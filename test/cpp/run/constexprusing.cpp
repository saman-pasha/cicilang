// a using-declaration, a using-directive and a namespace alias in the bodies of constant evaluations, which do nothing there
// (1.6.21): libc++ 23's __split_buffer swaps by `using std::swap; swap(__begin_, __begin);', and every push_back that grows a
// vector was no constant -- constexpr20.cpp's `sumv()' over libc++ 23
#include <utility>
#include <vector>
#include <cstdio>
namespace deep { namespace inner { constexpr int seven() { return 7; } } }
struct L {
  int *b = nullptr;
  constexpr void sw(int *&x) { using std::swap; swap(b, x); }
};
constexpr int f() { int a = 3; int *p = &a; L l; l.sw(p); return *l.b + (p == nullptr ? 1 : 0); }
constexpr int g() { using namespace deep::inner; return seven(); }
constexpr int h() { namespace di = deep::inner; return di::seven() + 1; }
constexpr int k() { using deep::inner::seven; int x = 1, y = 2; using std::swap; swap(x, y); return seven() * 10 + x; }
constexpr int grown() { std::vector<int> v; for (int i = 1; i <= 9; i++) v.push_back(i * i); int s = 0; for (int x : v) s += x; return s + (int) v.size(); }
int main() {
  static_assert(f() == 4);
  static_assert(g() == 7);
  static_assert(h() == 8);
  static_assert(k() == 72);
  static_assert(grown() == 294);
  std::printf("%d %d %d %d %d\n", f(), g(), h(), k(), grown());
  return 0;
}
