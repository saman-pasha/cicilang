// Two namespaces declare an enum of one name and enumerators of one name (0.127): each namespace reads its own.
#include <cstdio>
namespace n1 {
enum { x = 7 };
int get() { return x; }
enum Mode { Fast = 1, Slow = 2 };
int mode() { return Slow; }
int pick(Mode m) { return m == Fast ? 100 : 200; }
}
namespace n2 {
enum { x = 8 };
int get() { return x; }
enum Mode { Slow = 20, Fast = 10 };
int mode() { return Slow; }
int pick(Mode m) { return m == Fast ? 300 : 400; }
}
int main() {
  std::printf("%d %d %d %d %d %d\n", n1::get(), n2::get(), n1::x, n2::x, n1::mode(), n2::mode());
  n1::Mode a = n1::Fast;
  n2::Mode b = n2::Slow;
  std::printf("%d %d %d %d\n", (int)a, (int)b, n1::pick(a), n2::pick(b));
  std::printf("%d %d %d %d\n", (int)n2::Mode::Fast, (int)n1::Mode::Slow, n2::pick(n2::Fast), n1::pick(n1::Slow));
  return 0;
}
