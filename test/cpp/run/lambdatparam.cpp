// A generic lambda whose template parameters are named like a typedef some other function declares in a block: `using _Up = std::remove_reference_t<_Tp>;'
// joins the unit's one table, and the second parameter `const _Up &' of the lambda became `const _Tp &' -- `_Up' could not be deduced. A template parameter
// hides every outer name. libc++ 21 writes `__synth_three_way' as exactly such a lambda (C++20), and a vector's `<=>' is built on it.
#include <cstdio>
#include <type_traits>
#include <utility>
template <class _Tp> int blocktypedef(_Tp x) { using _Up = std::remove_reference_t<_Tp>; _Up y = x; return (int) sizeof(y); }
inline constexpr auto cmp = []<class _Tp, class _Up>(const _Tp &__t, const _Up &__u) { return __t < __u; };
template <class _Tp, class _Up = _Tp> using cmp_result = decltype(cmp(std::declval<_Tp &>(), std::declval<_Up &>()));
int main() {
  std::printf("%d %d %d %d\n", blocktypedef(3), blocktypedef(2.5), (int) cmp(1, 2), (int) cmp(2, 2.5));
  std::printf("%d %d\n", (int) std::is_convertible_v<cmp_result<int>, bool>, (int) std::is_convertible_v<cmp_result<int, double>, bool>);
  return 0;
}
