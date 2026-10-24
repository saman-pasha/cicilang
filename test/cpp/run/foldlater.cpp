// a fold over an enclosing pack and a generic lambda's own pack, expanded where both are bound ([temp.variadic]/5)
#include <cstdio>
#include <utility>
template <class... Ts>
int weigh(Ts... xs) {
  return [&]<std::size_t... Is>(std::index_sequence<Is...>) {
    int r = 0;
    ((r = r * 10 + xs * (int) (Is + 1)), ...);
    return r;
  }(std::make_index_sequence<sizeof...(Ts)>());
}
template <class... Ts>
long sum_scaled(Ts... xs) {
  return [&]<std::size_t... Is>(std::index_sequence<Is...>) {
    return (0L + ... + (long) (xs * (Is + 1)));
  }(std::make_index_sequence<sizeof...(Ts)>());
}
int main() {
  std::printf("%d %d %ld\n", weigh(1, 1, 2), weigh(3, 1, 4, 1, 5), sum_scaled(5, 6, 7));
  return 0;
}
