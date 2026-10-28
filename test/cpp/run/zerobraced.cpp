// `T{}' and `T()' of a scalar type named by a typedef are a value of THAT type (0.221; [expr.type.conv]/2): `std::uint8_t{}' was
// the int 0, so a template deduced int from it -- libc++ 21's `__impl(uint8_t{})' made `std::__countr_zero<int>', which failed
// its static assertion in every vectorized `std::mismatch' and `std::find' over ints
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <vector>
namespace ns { using u16 = unsigned short; }
template <class T> int f(T) { return (int) sizeof(T); }
int main() {
  auto l = [&]<class M>(M) { return (int) sizeof(M); };
  std::printf("%d %d %d %d %d\n", f(std::uint8_t{}), f(std::uint16_t()), f(ns::u16{}), f(std::size_t{}), l(std::uint64_t{}));
  std::printf("%d %d\n", (int) sizeof(std::uint64_t{}), (int) sizeof(std::int8_t{}));
  std::vector<int> v{3, 2, 1, 4}, u{3, 2, 5, 4};
  auto m = std::mismatch(v.begin(), v.end(), u.begin());
  std::printf("%d %d %d\n", *m.first, *m.second, (int) (std::find(v.begin(), v.end(), 4) - v.begin()));
}
