// A static member function the shipped library defines takes no `this' (0.127): `ios_base::sync_with_stdio(true)' was called
// with a null first, which the library read as its bool, and `locale::global(loc)' with a null for its locale.
#include <cstdio>
#include <ios>
#include <locale>
int main() {
  bool a = std::ios_base::sync_with_stdio(false);
  bool b = std::ios_base::sync_with_stdio(true);
  bool c = std::ios_base::sync_with_stdio(true);
  int i1 = std::ios_base::xalloc(), i2 = std::ios_base::xalloc();
  std::printf("%d %d %d %d\n", a, b, c, i2 - i1);
  std::locale prev = std::locale::global(std::locale::classic());
  std::printf("%s %s\n", std::locale::classic().name().c_str(), prev.name().c_str());
  return 0;
}
