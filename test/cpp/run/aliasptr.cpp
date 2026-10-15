// The qualification conversion of pointers whose pointee is spelled through a program's alias of a class on one side
// and as the class on the other: `SV *' to `const std::string_view *' (libc++ 21's common_reference asks it, and
// with it `ranges::lower_bound' over a projection that returns a string_view, as std::chrono's time zone database does)
#include <algorithm>
#include <concepts>
#include <cstdio>
#include <iterator>
#include <string>
#include <string_view>
#include <type_traits>
#include <vector>
using SV = std::string_view;
struct Zone {
  std::string n;
  int off;
  SV name() const noexcept { return n; }
};
using It = std::vector<Zone>::const_iterator;
struct Box { int v; };
using B2 = Box;
int find(const std::vector<Zone> &zs, SV name) {
  if (auto it = std::ranges::lower_bound(zs, name, {}, &Zone::name); it != zs.end() && it->name() == name)
    return it->off;
  return 99;
}
int main() {
  std::printf("%d\n", (int) std::indirectly_readable<std::projected<It, decltype(&Zone::name)>>);
  std::printf("%d %d %d\n", (int) std::is_convertible_v<SV *, const std::string_view *>,
              (int) std::is_convertible_v<B2 *, const Box *>, (int) std::is_convertible_v<const B2 *, Box *>);
  std::printf("%d %d\n", (int) std::common_reference_with<SV &&, const std::string_view &>,
              (int) std::is_same_v<std::common_reference_t<B2 &&, const Box &>, const Box &>);
  std::vector<Zone> zs{{"America/New_York", -5}, {"Etc/UTC", 0}, {"Europe/Paris", 1}};
  std::printf("%d %d %d\n", find(zs, "Etc/UTC"), find(zs, "Europe/Paris"), find(zs, "Mars/Base"));
  return 0;
}
