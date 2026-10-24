// a static aggregate member initialized by a call of its class's own constexpr function (libc++ 21's <regex>, <mdspan>)
#include <array>
#include <cstdio>
template <class T, T... Vs>
struct PS {
  static constexpr std::array<T, sizeof...(Vs)> make() {
    T vals[sizeof...(Vs)] = {Vs...};
    std::array<T, sizeof...(Vs)> sums{{}};
    T run = 0;
    for (int i = 0; i != (int) sizeof...(Vs); i++) {
      sums[i] = run;
      run += vals[i];
    }
    return sums;
  }
  static constexpr std::array<T, sizeof...(Vs)> result{make()};
  static constexpr T get(std::size_t i) { return result[i]; }
};
int main() {
  using P = PS<int, 3, 4, 5, 6>;
  std::printf("%d %d %d %d\n", P::get(0), P::get(1), P::get(2), P::get(3));
  constexpr int k = P::get(3);
  std::printf("%d\n", k);
  return 0;
}
