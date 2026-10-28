// std::size at C++23 with <algorithm> alone: libc++'s <algorithm> holds ranges::size and no std::size at C++23, where
// clang++ says "no member named 'size' in namespace 'std'"; the call is refused by name, never sent to the object (0.221)
#include <algorithm>
#include <cstdio>
int main() {
  int a[4] = {};
  std::printf("%d\n", (int)std::size(a));
  return 0;
}
