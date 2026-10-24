// a temporary built in a conditionally evaluated operand is destroyed only where it was built ([class.temporary]/4)
#include <cstdio>
struct T {
  int v;
  T(int x) : v(x) { std::printf("T(%d)\n", v); }
  ~T() { std::printf("~T(%d)\n", v); }
  bool ok() const { return v > 0; }
  int get() const { return v; }
};
bool yes() { return true; }
bool no() { return false; }
int main() {
  bool r1 = yes() || T(5).ok();
  std::printf("r1 %d\n", r1);
  bool r2 = no() || T(6).ok();
  std::printf("r2 %d\n", r2);
  bool r3 = no() && T(7).ok();
  std::printf("r3 %d\n", r3);
  bool r4 = yes() && T(8).ok() && T(9).ok();
  std::printf("r4 %d\n", r4);
  int c = yes() ? T(1).get() : T(2).get();
  std::printf("c %d\n", c);
  int d = no() ? T(3).get() : T(4).get();
  std::printf("d %d\n", d);
  if (no() || T(10).ok()) std::printf("in if\n");
  std::printf("end\n");
  return 0;
}
