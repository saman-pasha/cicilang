// A NESTED expansion of the pack being expanded sees the whole pack ([temp.variadic]/5): `Ts...' inside the pattern of
// a fold or an expansion over Ts, `sizeof...(Ts)' inside it, a nested fold, and a function parameter pack likewise.
#include <type_traits>
#include <cstdio>
template <class... Ts> constexpr bool all_common = (std::is_same_v<std::common_type_t<Ts...>, Ts> && ...);
template <class... Ts> constexpr bool any_common = (std::is_same_v<std::common_type_t<Ts...>, Ts> || ...);
template <class... Ts> constexpr int sized = ((sizeof...(Ts) == 3 && std::is_integral_v<Ts>) + ...);
template <class... Ts> constexpr int nested = ((sizeof(Ts) * (sizeof(Ts) + ...)) + ...);
template <class... Ts> concept Common = (std::is_convertible_v<Ts, std::common_type_t<Ts...>> && ...);
int sum(int a, int b, int c) { return a + b + c; }
template <class... As> int spread(As... xs) { return ((xs * sum(xs...)) + ...); }
int main() {
  std::printf("%d %d %d %d\n", (int) all_common<int, long>, (int) any_common<int, long>, (int) all_common<long, long>, sized<int, long, short>);
  std::printf("%d %d %d\n", nested<char, short>, (int) Common<int, long, short>, spread(1, 2, 3));
  return 0;
}
