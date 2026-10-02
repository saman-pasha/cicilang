// views::transform through the pipe (C++20): the view's iterator, a member class template of transform_view
#include <cstdio>
#include <ranges>
#include <vector>
int main() {
  std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8};
  for (int x : v | std::views::transform([](int n) { return n * n; })) std::printf("%d ", x);
  std::printf("\n");
  return 0;
}
