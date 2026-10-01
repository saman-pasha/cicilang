// copy-initialization from std::move and from an xvalue cast chooses the MOVE constructor (a vector's and the program's own)
#include <vector>
#include <cstdio>
static int moved = 0, copied = 0;
struct M { int v; M(int x) : v(x) {} M(const M &o) : v(o.v) { copied++; } M(M &&o) : v(o.v) { o.v = 0; moved++; } };
int main() {
  std::vector<int> a = {1, 2, 3};
  std::vector<int> b(std::move(a));
  std::vector<int> c = {4, 5};
  std::vector<int> d = static_cast<std::vector<int> &&>(c);
  M m1(5); M m2 = std::move(m1);
  std::printf("%d %d %d %d %d %d %d\n", (int) a.size(), (int) b.size(), (int) c.size(), (int) d.size(), m1.v, moved, copied);
  return 0;
}
