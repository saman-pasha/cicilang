// views::reverse, a range adaptor closure object used bare in the pipe (C++20)
#include <cstdio>
#include <ranges>
#include <vector>
int main() {
  std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8};
  for (int x : v | std::views::reverse) std::printf("%d ", x);
  std::printf("\n");
  return 0;
}
