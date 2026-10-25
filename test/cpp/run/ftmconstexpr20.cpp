// libc++'s constexpr facilities of C++20 by their feature-test macros (0.206): sort over an array, a vector, complex
// arithmetic, tuple and structured bindings, optional and variant, invoke and the transparent functors, string and
// string_view, reverse iterators and swap, pair's comparison and exchange -- each folded at compile time.
#include <algorithm>
#include <array>
#include <complex>
#include <cstdio>
#include <functional>
#include <iterator>
#include <numeric>
#include <optional>
#include <string>
#include <string_view>
#include <tuple>
#include <utility>
#include <variant>
#include <vector>

constexpr int sorted_third() {
  std::array<int, 5> a{5, 3, 9, 1, 7};
  std::sort(a.begin(), a.end());
  return a[2];
}
constexpr int vec_sum() {
  std::vector<int> v(4);
  std::iota(v.begin(), v.end(), 1);
  std::reverse(v.begin(), v.end());
  return std::accumulate(v.begin(), v.end(), 0) * 10 + v.front();
}
constexpr double cplx() {
  std::complex<double> z(1.0, 2.0), w(3.0, -1.0);
  auto r = z * w + std::complex<double>(0.5, 0.5);
  return r.real() * 10 + r.imag();
}
constexpr int tup() {
  std::tuple<int, char, long> t{4, 'b', 6L};
  auto [a, b, c] = t;
  std::get<0>(t) = 9;
  return std::get<0>(t) * 100 + a * 10 + (b - 'a') + int(c) * 1000;
}
constexpr int opt() {
  std::optional<int> o;
  int r = o.value_or(3);
  o = 8;
  std::variant<int, double> var{std::in_place_index<0>, 4};
  return r * 100 + *o * 10 + std::get<int>(var);
}
constexpr int inv() { return std::invoke([](int a, int b) { return a - b; }, 10, 4) + std::plus<>{}(1, 2); }
constexpr int strs() {
  std::string s = "abc";
  s += "def";
  std::string_view sv = "constexpr";
  return int(s.size()) * 100 + int(sv.find("exp")) * 10 + int(std::count(sv.begin(), sv.end(), 'c'));
}
constexpr int iters() {
  std::array<int, 4> a{1, 2, 3, 4};
  auto r = std::make_reverse_iterator(a.end());
  int x = *r;
  std::swap(a[0], a[3]);
  return x * 10 + a[0];
}
constexpr bool pairs() {
  std::pair<int, int> p{1, 2}, q{1, 3};
  return p < q && std::exchange(p.first, 5) == 1 && p.first == 5;
}

int main() {
  static_assert(sorted_third() == 5);
  constexpr int a = sorted_third(), b = vec_sum(), d = tup(), e = opt(), f = inv(), g = strs(), h = iters();
  constexpr double c = cplx();
  constexpr bool i = pairs();
  std::printf("%d %d %.1f %d %d %d %d %d %d\n", a, b, c, d, e, f, g, h, (int) i);
}
