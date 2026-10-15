// The difference of an iota_view's iterator and sentinel, both ways, over a const view and a plain one: the friend
// operator- of the iterator and of the sentinel, which name the view's own types.
#include <ranges>
#include <cstdio>
int main() {
  auto v = std::views::iota(0, 5);
  const auto &cv = v;
  long d = cv.end() - cv.begin();
  long e = v.begin() - v.end();
  std::printf("%ld %ld\n", d, e);
  return 0;
}
