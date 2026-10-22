// libc++ 22's C++23 views over a vector: pairwise, adjacent<3>, zip_transform and adjacent_transform<2> (P2321, zip,
// which libc++ 18 and 21 do not ship: zipadjacent.needs).
#include <cstdio>
#include <ranges>
#include <vector>

int main() {
  std::vector<int> v{1, 2, 3, 4, 5};
  int s = 0;
  for (auto [a, b] : v | std::views::pairwise)
    s += a * b;
  std::printf("pairwise %d\n", s);
  int t = 0;
  for (auto [a, b, c] : v | std::views::adjacent<3>)
    t += a + b * c;
  std::printf("adjacent %d\n", t);
  std::vector<int> w{10, 20, 30};
  for (int x : std::views::zip_transform([](int p, int q) { return p * q; }, v, w))
    std::printf("zt %d\n", x);
  for (int x : v | std::views::adjacent_transform<2>([](int p, int q) { return q - p; }))
    std::printf("at %d\n", x);
  return 0;
}
