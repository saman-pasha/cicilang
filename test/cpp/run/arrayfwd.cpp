// `for (auto &&x : a)' over a std::array binds a reference to `*it' of a raw pointer: the safe part takes it as a
// borrow of the array, not as fresh memory (`plain pointer not consumed' before 0.132).
#include <array>
#include <string_view>
#include <cstdio>
int main() {
  std::array<int, 3> a{1, 2, 3};
  int s = 0;
  for (auto&& x : a) s += x;
  std::printf("%d\n", s);
  return 0;
}
