// C++20's range views on libc++ 18 (0.112): views::filter called and through the pipe, a capturing predicate,
// two filters chained, and the view's begin/end walked by hand
#include <cstdio>
#include <ranges>
#include <vector>
int main() {
  std::vector<int> v{1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
  for (int x : std::views::filter(v, [](int x) { return x % 2 == 0; })) std::printf("%d ", x);
  std::printf("\n");
  int k = 6;
  for (int x : v | std::views::filter([k](int x) { return x > k; })) std::printf("%d ", x);
  std::printf("\n");
  auto odd = v | std::views::filter([](int x) { return x % 2 == 1; });
  int sum = 0, n = 0;
  for (auto it = odd.begin(); it != odd.end(); ++it) { sum += *it; n++; }
  std::printf("%d %d\n", sum, n);
  for (int x : v | std::views::filter([](int x) { return x > 3; }) | std::views::filter([](int x) { return x % 3 == 0; })) std::printf("%d ", x);
  std::printf("\n");
  return 0;
}
