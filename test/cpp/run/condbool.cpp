// a conditional's condition contextually converted to bool ([expr.cond]/1, 0.137): an explicit operator bool and an optional
#include <cstdio>
#include <optional>
struct B { int v; explicit operator bool() const { return v != 0; } };
int f(const std::optional<int> &o) { return o ? *o : -1; }
int main() {
  B b{3}, z{0};
  std::optional<int> e;
  std::printf("%d %d %d %d\n", b ? 1 : 2, z ? 1 : 2, f(7), f(e));
  return 0;
}
