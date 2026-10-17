// A header's names that two of its namespaces declare, NAMED -- not called -- through a using of the deeper one (0.161): a
// type, an object, a function template's address, each the deeper namespace's as clang++ has it. The flattening keys
// ranges::less `ranges.less' apart from std::less, ranges::begin `ranges.begin' apart from std::begin, chrono::abs
// `chrono.abs' apart from the C library's abs; a bare name was the outer one's.
#include <chrono>
#include <cstdio>
#include <functional>
#include <ranges>
#include <type_traits>
#include <vector>
using std::ranges::greater;                      // a using-declaration of a keyed type at namespace scope
namespace demo {
using namespace std::ranges;                     // a using-directive at namespace scope, in force to the namespace's end
int lt(int a, int b) {
  less l;                                        // the class ranges::less: std::less is a template
  return l(a, b) ? 1 : 0;
}
int first(std::vector<int> &v) {
  auto b = begin;                                // the object ranges::begin, read
  return *b(v);
}
constexpr bool same = std::is_same_v<less, std::ranges::less>;
}
int main() {
  std::vector<int> v{7, 1, 2};
  greater g;
  int r = 0;
  {
    using namespace std::chrono;                 // ... and in a block
    std::chrono::seconds (*a)(std::chrono::seconds) = &abs<long long, std::ratio<1>>;
    r = (int) a(std::chrono::seconds(-5)).count();
  }
  std::printf("%d %d %d %d %d %d\n", demo::lt(1, 2), demo::lt(2, 1), demo::first(v), (int) demo::same, g(3, 2) ? 1 : 0, r);
  return 0;
}
