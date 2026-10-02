// An enumeration is a scalar and no arithmetic type, and an operand of enumeration type takes the program's own
// operator ([over.match.oper]/1): std::find over an enum compares through the program's operator==, never memcmp.
#include <algorithm>
#include <cstdio>
#include <type_traits>
enum class E { a, b, c, d };
bool operator==(E x, E y) { return (int) x / 2 == (int) y / 2; }
enum F { x0, x1 };
template <class T> bool same(const T &u, const T &v) { return u == v; }
int main() {
  E arr[] = {E::c, E::a, E::d};
  E p = E::a, q = E::b;
  std::printf("%d %d\n", (int) (std::find(arr, arr + 3, E::b) - arr), (int) (std::find(arr, arr + 3, E::d) - arr));
  std::printf("%d %d %d\n", (int) (p == q), (int) (E::c == E::a), (int) same(p, q));
  std::printf("%d %d %d %d %d %d\n", (int) std::is_integral_v<E>, (int) std::is_integral_v<F>, (int) std::is_enum_v<E>,
              (int) std::is_scalar_v<E>, (int) std::is_arithmetic_v<F>, (int) std::is_signed_v<F>);
  return 0;
}
