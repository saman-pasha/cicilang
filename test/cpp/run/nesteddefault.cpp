#include <cstdio>
struct H { void *p = nullptr; H() = default; H(int) {} };
struct Outer {
  struct In { int r = 5; H h; };
  int f() { In x; return x.r + (x.h.p == nullptr ? 10 : 20); }
};
int main() {
  Outer::In y;
  Outer o;
  printf("%d %d %d\n", y.r, y.h.p == nullptr, o.f());
  return 0;
}
