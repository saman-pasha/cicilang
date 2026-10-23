// [[no_unique_address]] in libc++'s own types (0.198): libc++ 18 asks __has_cpp_attribute(no_unique_address), which was 0
// here, and laid out its algorithm results and its views without the attribute -- otherwise than clang++'s build does
#include <algorithm>
#include <cstdio>
#include <ranges>
#include <vector>
struct E {};
int main() {
  std::vector<int> v{1, 2, 3};
  auto t = v | std::views::transform([](int x) { return x * 2; });
  std::printf("%d %d %d\n", (int) sizeof(std::ranges::in_out_result<E, int *>), (int) sizeof(std::ranges::in_in_result<E, int>), (int) sizeof(t));
  int out[3];
  auto r = std::ranges::copy(v, out);
  int s = 0;
  for (int x : t) s += x;
  std::printf("%d %d %d\n", (int) (r.out - out), out[2], s);
}
