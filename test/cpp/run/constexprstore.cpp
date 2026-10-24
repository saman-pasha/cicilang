// a constant built by a constexpr function that stores through a call returning a reference, std::array's operator[]
#include <array>
#include <cstdio>
constexpr std::array<int, 4> squares() {
  std::array<int, 4> a{};
  for (int i = 0; i < 4; i++) a[i] = i * i;
  return a;
}
constexpr std::array<int, 4> r = squares();
int main() {
  std::printf("%d %d %d %d\n", r[0], r[1], r[2], r[3]);
  static_assert(r[3] == 9, "squares");
  return 0;
}
