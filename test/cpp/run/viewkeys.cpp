// views::keys and views::values over a map (C++20): elements<0> and elements<1>, a variable template whose value is an object
#include <cstdio>
#include <map>
#include <ranges>
#include <vector>
int main() {
  std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8};
  std::map<int, char> m = {{1, 'a'}, {2, 'b'}};
  for (int k : m | std::views::keys) std::printf("%d ", k);
  for (char c : m | std::views::values) std::printf("%c ", c);
  (void) v;
  std::printf("\n");
  return 0;
}
