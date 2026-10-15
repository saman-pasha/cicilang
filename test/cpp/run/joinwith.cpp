// views::join_with (C++23): its class's constraint __concatable folds over a pack whose pattern holds a nested
// expansion of the same pack, `(__impl<__concat_reference_t<_Rs...>, ..., iterator_t<_Rs>> && ...)'.
#include <ranges>
#include <string>
#include <vector>
#include <cstdio>
int main() {
  std::vector<std::string> vs{"ab", "c", "def"};
  std::string out;
  for (char c : std::views::join_with(vs, ',')) out += c;
  std::vector<std::vector<int>> vv{{1, 2}, {3}, {4, 5}};
  int n = 0, s = 0;
  for (int x : vv | std::views::join_with(0)) { ++n; s += x; }
  std::printf("%s %d %d\n", out.c_str(), n, s);
  return 0;
}
