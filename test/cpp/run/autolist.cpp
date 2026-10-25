// `auto x{e}' deduces from its one item, as `auto x = e' ([dcl.type.auto.deduct]/4, C++17), and `auto x = {e}' and
// `auto x = {a, b}' deduce std::initializer_list (0.206): both forms were refused `auto(x)'.
#include <cstdio>
#include <initializer_list>
#include <type_traits>
int main() {
  auto y{5};
  auto w{7.5};
  const auto c{'c'};
  auto &r{y};
  auto *p{&y};
  auto z = {6};
  auto zz = {1, 2, 3};
  r += 1;
  std::printf("%d %d %d %d %d\n", (int) std::is_same_v<decltype(y), int>, (int) std::is_same_v<decltype(w), double>,
              (int) std::is_same_v<decltype(c), const char>, (int) std::is_same_v<decltype(r), int &>,
              (int) std::is_same_v<decltype(p), int *>);
  std::printf("%d %d %zu %zu\n", (int) std::is_same_v<decltype(z), std::initializer_list<int>>,
              (int) std::is_same_v<decltype(zz), std::initializer_list<int>>, z.size(), zz.size());
  int s = 0;
  for (int x : zz) s += x;
  std::printf("%d %.1f %c %d %d %d\n", y, w, c, *p, *z.begin(), s);
}
