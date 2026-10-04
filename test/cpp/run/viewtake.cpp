// views::take through the pipe (C++20): take_view over a sized random-access range
#include <cstdio>
#include <ranges>
#include <vector>
int main() {
  std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8};
  for (int x : v | std::views::take(3)) std::printf("%d ", x);
  std::printf("\n");
  return 0;
}
