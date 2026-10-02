// a class with a copy constructor and no move constructor in a vector: copied at a push, a growth and an erase
#include <vector>
#include <cstdio>
static int copies = 0, dtors = 0;
struct C { int v; C(int x) : v(x) {} C(const C &o) : v(o.v) { copies++; } C &operator=(const C &o) { v = o.v; return *this; } ~C() { dtors++; } };
int main() {
  std::vector<C> v; v.reserve(4);
  std::printf("a %d %d\n", copies, dtors);
  v.push_back(C(1)); std::printf("b %d %d\n", copies, dtors);
  C c2(2); v.push_back(c2); std::printf("c %d %d\n", copies, dtors);
  v.emplace_back(4); std::printf("d %d %d\n", copies, dtors);
  v.reserve(8); std::printf("e %d %d\n", copies, dtors);
  v.erase(v.begin()); std::printf("f %d %d\n", copies, dtors);
  return 0;
}
