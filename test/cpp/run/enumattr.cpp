#include <cstdio>
// an attribute after `enum' and its key ([dcl.enum]/1): read and dropped, the enum named and its enumerators its own
enum [[deprecated]] E { a = 1, b = 4 };
enum class [[nodiscard]] F : unsigned char { c = 7 };
enum __attribute__((__deprecated__)) G { d = 2 };
enum struct [[maybe_unused]] H { e = 9 };
template <class T> int pick(T) { return 1; }
template <> int pick(E) { return 2; }
int main() {
  E x = b;
  F y = F::c;
  G z = d;
  H w = H::e;
  std::printf("%d %d %d %d %zu %zu %d %d\n", (int) x, (int) y, (int) z, (int) w, sizeof(F), sizeof(G), pick(x), pick(0));
  return 0;
}
