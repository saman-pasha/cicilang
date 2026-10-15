// Abbreviated function templates with a PARAMETER PACK of `auto', constrained or not: `long sum(auto... xs)',
// `Small auto... xs', a lambda's `std::integral auto... v', an empty pack, and `pick(auto)' against `pick(Small auto...)'.
#include <concepts>
#include <cstdio>
template <class T> concept Small = sizeof(T) <= 4;
long sum(auto... xs) { return (0L + ... + xs); }
long sum_small(Small auto... xs) { return (0L + ... + xs); }
long pick(auto x) { return 100 + x; }
long pick(Small auto... xs) { return (0L + ... + xs); }
int main() {
  auto lam = [](std::integral auto... v) { return (long) sizeof...(v); };
  std::printf("%ld %ld %ld %ld\n", sum(1, 2L, 3), sum_small(1, 2, 3), lam(1, 2), sum());
  std::printf("%ld %ld\n", pick(5L), pick(1, 2));
  return 0;
}
