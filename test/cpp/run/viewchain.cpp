// filter | transform | take chained through the pipe (C++20): views over views, each a library class template
#include <cstdio>
#include <ranges>
#include <vector>
int main() {
  std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8};
  for (int x : v | std::views::filter([](int n) { return n % 2 == 0; }) | std::views::transform([](int n) { return n + 100; }) | std::views::take(2)) std::printf("%d ", x);
  std::printf("\n");
  return 0;
}
