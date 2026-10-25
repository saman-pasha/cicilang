#include <cstdio>
#include <tuple>
struct R { int v; };
R get(int k) { return R{k * 2}; }
R grab(int k) { return R{k * 3}; }
int main() {
  std::tuple<R> t(get(4));
  R y = R(get(3)), z = R(grab(3));
  std::printf("%d %d %d %d\n", std::get<0>(t).v, get(5).v, y.v, z.v);
  return 0;
}
