// a class of one namespace and a function of another across the headers' reads (0.221): libc++ 21's <format> at C++23 holds
// std::ranges' class __upper_bound bare, <algorithm> std's function template __upper_bound, and with <format> read first
// `std::ranges::upper_bound', whose object is `__upper_bound{}', called the function with no argument
#include <format>
#include <algorithm>
#include <cstdio>
#include <vector>
int main() {
  std::vector<int> v{1, 2, 4, 8};
  auto a = std::upper_bound(v.begin(), v.end(), 3);
  auto b = std::ranges::upper_bound(v, 3);
  auto c = std::lower_bound(v.begin(), v.end(), 4);
  std::printf("%d %d %d %s\n", (int)(a - v.begin()), (int)(b - v.begin()), (int)(c - v.begin()), std::format("{}", *a).c_str());
  return 0;
}
