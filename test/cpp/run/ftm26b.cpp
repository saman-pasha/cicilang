// libc++ 21's C++26 facilities by their feature-test macros (0.206): not_fn over a function as a template argument,
// variant's member visit, reference_wrapper's comparisons, the string streams and string's operator+ over a
// string_view, constexpr list, forward_list, stable_sort and inplace_merge, is_sufficiently_aligned and
// aligned_accessor.
#include <algorithm>
#include <array>
#include <cstdio>
#include <forward_list>
#include <functional>
#include <list>
#include <mdspan>
#include <memory>
#include <iterator>
#include <sstream>
#include <string>
#include <string_view>
#include <variant>
#include <vector>

constexpr bool is_odd(int x) { return x % 2 != 0; }

constexpr int clist() {
  std::list<int> l{3, 1, 2};
  l.sort();
  l.push_front(9);
  std::forward_list<int> f{5, 6};
  f.push_front(4);
  return l.front() * 1000 + l.back() * 100 + f.front() * 10 + int(std::distance(f.begin(), f.end()));
}
constexpr int cstable() {
  std::array<int, 6> a{4, 1, 3, 1, 2, 0};
  std::stable_sort(a.begin(), a.end());
  std::inplace_merge(a.begin(), a.begin() + 3, a.end());
  return a[0] * 100 + a[3] * 10 + a[5];
}

int main() {
  auto even = std::not_fn<is_odd>();
  std::printf("not_fn_nttp %d %d\n", (int) even(4), (int) even(3));
  std::variant<int, std::string> v = std::string("seven");
  auto n = v.visit([](const auto &x) -> int {
    if constexpr (std::is_same_v<std::decay_t<decltype(x)>, int>) return x; else return int(x.size());
  });
  int got = v.visit<int>([](const auto &) { return 42; });
  std::printf("variant_visit %d %d\n", n, got);
  int a = 1, b = 2;
  auto ra = std::ref(a), rb = std::ref(b);
  std::printf("reference_wrapper %d %d %d\n", (int) (ra < rb), (int) (ra == 1), (int) (ra <=> rb < 0));
  std::string_view sv = "12 34";
  std::istringstream is(sv);
  int x = 0, y = 0;
  is >> x >> y;
  std::ostringstream os(std::string_view("pre"));
  std::printf("sstream_sv %d %d %zu\n", x, y, os.str().size());
  std::string s = "ab";
  std::string t = s + std::string_view("cd");
  std::string u = std::string_view("xy") + s;
  std::printf("string_sv %s %s\n", t.c_str(), u.c_str());
  constexpr int cl = clist(), cs = cstable();
  std::printf("constexpr %d %d\n", cl, cs);
  alignas(16) static int buf[8] = {0, 1, 2, 3, 4, 5, 6, 7};
  std::printf("is_sufficiently_aligned %d\n", (int) std::is_sufficiently_aligned<16>(buf));
  std::mdspan<int, std::dims<1>, std::layout_right, std::aligned_accessor<int, 16>> m(buf, 8);
  std::printf("aligned_accessor %d %zu\n", m[3], m.extent(0));
}
