// The range views and adaptors beyond filter (C++20): transform, take, drop, reverse, iota, take_while, keys, values,
// chained through the pipe and walked by a range-for
#include <cstdio>
#include <map>
#include <ranges>
#include <vector>
int main() {
  std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8};
  for (int x : v | std::views::transform([](int n) { return n * n; })) std::printf("%d ", x);
  std::printf("\n");
  for (int x : v | std::views::take(3)) std::printf("%d ", x);
  std::printf("\n");
  for (int x : v | std::views::drop(5)) std::printf("%d ", x);
  std::printf("\n");
  for (int x : v | std::views::reverse) std::printf("%d ", x);
  std::printf("\n");
  for (int x : std::views::iota(3, 7)) std::printf("%d ", x);
  std::printf("\n");
  for (int x : v | std::views::take_while([](int n) { return n < 4; })) std::printf("%d ", x);
  std::printf("\n");
  std::map<int, char> m = {{1, 'a'}, {2, 'b'}};
  for (int k : m | std::views::keys) std::printf("%d ", k);
  for (char c : m | std::views::values) std::printf("%c ", c);
  std::printf("\n");
  for (int x : v | std::views::filter([](int n) { return n % 2 == 0; }) | std::views::transform([](int n) { return n + 100; }) | std::views::take(2)) std::printf("%d ", x);
  std::printf("\n");
  return 0;
}
