// views::iota(3, 7) (C++20): iota_view walked by a range-for
#include <cstdio>
#include <ranges>
#include <vector>
int main() {
  std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8};
  for (int x : std::views::iota(3, 7)) std::printf("%d ", x);
  (void) v;
  std::printf("\n");
  return 0;
}
