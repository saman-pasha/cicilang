// std::compare_three_way and std::common_comparison_category (0.104): a constrained member template operator()
// called on a library object, and a deduced `auto' result over an `if constexpr' chain whose first return is
// in a discarded branch (libc++'s __get_comp_type), decayed of its top-level const
#include <cstdio>
#include <compare>
#include <type_traits>
struct P { int v; };
template <class... Ts> constexpr auto pick() {
  constexpr int k = sizeof...(Ts);
  if constexpr (k == 0) return void();
  else if constexpr (k == 1) return 1;
  else return P{2};
}
template <class... Ts> struct CC { using type = decltype(pick<Ts...>()); };
template <class... Ts> using CC_t = typename CC<Ts...>::type;
struct Q { int a; auto operator<=>(const Q &) const = default; bool operator==(const Q &) const = default; };
int main() {
  std::compare_three_way cmp;
  std::strong_ordering o = cmp(3, 5);
  std::partial_ordering po = std::compare_three_way{}(1.5, 0.5);
  std::strong_ordering oq = cmp(Q{1}, Q{1});
  printf("%d %d %d %d\n", (int) (o < 0), (int) (po > 0), (int) (oq == 0), (int) std::is_eq(cmp(7, 7)));
  using C = std::common_comparison_category_t<std::strong_ordering, std::partial_ordering>;
  printf("%d %d %d %d\n", (int) std::is_same_v<C, std::partial_ordering>,
         (int) std::is_same_v<std::common_comparison_category_t<std::strong_ordering, std::weak_ordering>, std::weak_ordering>,
         (int) std::is_same_v<std::common_comparison_category_t<std::strong_ordering, std::strong_ordering>, std::strong_ordering>,
         (int) std::is_same_v<std::common_comparison_category_t<>, std::strong_ordering>);
  printf("%d %d %d %d\n", (int) std::is_same_v<CC_t<int, int>, P>, (int) std::is_same_v<CC<int>::type, int>,
         (int) std::is_same_v<CC_t<int>, int>, (int) std::is_void_v<CC_t<>>);
  printf("%d\n", (int) std::is_void_v<std::common_comparison_category_t<int>>);
  return 0;
}
