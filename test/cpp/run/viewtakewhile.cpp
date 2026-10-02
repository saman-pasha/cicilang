// views::take_while through the pipe (C++20): the view's sentinel, a member class template
#include <cstdio>
#include <ranges>
#include <vector>
int main() {
  std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8};
  for (int x : v | std::views::take_while([](int n) { return n < 4; })) std::printf("%d ", x);
  std::printf("\n");
  return 0;
}
