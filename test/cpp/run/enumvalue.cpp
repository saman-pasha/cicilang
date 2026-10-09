// value-initialization of an enum by a functional cast with no argument or an empty braced list (0.117, [dcl.init]/8): `E()' and `E{}' are the
// enum's zero -- <charconv>'s `r.ec == std::errc()' compares an error code with it. A cast with one argument, `E(1)', ran before
#include <cstdio>
namespace ns { enum class E { a, b }; enum F { f0, f1 }; }
using ns::E;
int main() {
  ns::E e = ns::E();
  ns::F f = ns::F();
  ns::E g = ns::E{};
  E h = E();
  E k = E(1);
  std::printf("%d %d %d %d %d\n", (int)e, (int)f, (int)g, (int)h, (int)k);
  std::printf("%d %d\n", (int)(e == ns::E()), (int)(ns::E::b == ns::E()));
  return 0;
}
