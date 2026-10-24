// A conditional noexcept that is false does not guard the body: an exception leaves it (0.199)
#include <cstdio>
#include <vector>
template <class T> void thrower(T v) noexcept(sizeof(T) > 100) { throw (int) v; }
struct C {
  int v;
  C(int x) : v(x) {}
  C(const C &o) : v(o.v) { std::printf("copy %d\n", v); }
  C(C &&o) noexcept(sizeof(int) > 8) : v(o.v) { std::printf("move %d\n", v); }
};
struct D {
  int v;
  D(int x) : v(x) {}
  D(const D &o) : v(o.v) { std::printf("copy %d\n", v); }
  D(D &&o) noexcept(sizeof(int) < 8) : v(o.v) { std::printf("move %d\n", v); }
};
int main() {
  try { thrower(7); } catch (int e) { std::printf("caught %d\n", e); }
  std::vector<C> c;
  c.reserve(1);
  c.emplace_back(1);
  c.emplace_back(2);
  std::vector<D> d;
  d.reserve(1);
  d.emplace_back(3);
  d.emplace_back(4);
  std::printf("%d %d\n", c[0].v + c[1].v, d[0].v + d[1].v);
}
