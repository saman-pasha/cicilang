// A structured binding over a prvalue of std::ranges::subrange, const and not: the tuple protocol's `get' is found in
// the class's own namespace, and the hidden object is built once.
#include <cstdio>
#include <ranges>
int main() {
  std::ranges::single_view<char> sv{'x'};
  const auto [b, e] = std::ranges::subrange{sv};
  auto [b2, e2] = std::ranges::subrange{sv};
  std::printf("%d %d %c\n", (int) (e - b), (int) (e2 - b2), *b);
  return 0;
}
