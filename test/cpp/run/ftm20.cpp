// libc++'s C++20 facilities by their feature-test macros (0.206): assume_aligned, endian, the integer comparisons,
// lerp and midpoint, ssize (a decltype in a template-id's arguments), to_address, to_array (P (&&)[N] deduced from a
// braced list), unwrap_reference, type_identity, the array bounds traits, remove_cvref, shift_left and shift_right,
// make_unique_for_overwrite and make_shared of an array, starts_with and ends_with, list's remove answering a count,
// heterogeneous unordered lookup, <bit>, bind_front, identity and is_constant_evaluated.
#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstdio>
#include <functional>
#include <list>
#include <memory>
#include <numeric>
#include <string>
#include <string_view>
#include <type_traits>
#include <unordered_map>
#include <utility>
#include <vector>

struct SHash {
  using is_transparent = void;
  std::size_t operator()(std::string_view s) const { return std::hash<std::string_view>{}(s); }
};
struct SEq {
  using is_transparent = void;
  bool operator()(std::string_view a, std::string_view b) const { return a == b; }
};

int main() {
  alignas(16) int arr[4] = {1, 2, 3, 4};
  int *p = std::assume_aligned<16>(arr);
  std::printf("assume_aligned %d\n", p[2]);
  std::printf("endian %d\n", (int) (std::endian::native == std::endian::little));
  std::printf("cmp %d %d %d %d\n", (int) std::cmp_less(-1, 0u), (int) (-1 < 0u), (int) std::cmp_greater_equal(5u, -3),
              (int) std::in_range<unsigned char>(300));
  std::printf("lerp %.2f midpoint %d %.2f\n", std::lerp(2.0, 10.0, 0.25), std::midpoint(3, 8), std::midpoint(1.0, 4.0));
  std::vector<int> v{5, 4, 3};
  std::printf("ssize %td %d\n", std::ssize(v), (int) std::is_signed_v<decltype(std::ssize(v))>);
  auto up = std::make_unique<int>(9);
  std::printf("to_address %d\n", *std::to_address(up));
  auto ta = std::to_array({7, 8, 9});
  auto tc = std::to_array("hey");
  std::printf("to_array %zu %d %zu %c\n", ta.size(), ta[1], tc.size(), tc[1]);
  int k = 3;
  auto rw = std::ref(k);
  std::printf("unwrap %d %d\n", (int) std::is_same_v<std::unwrap_ref_decay_t<decltype(rw)>, int &>,
              (int) std::is_same_v<std::unwrap_reference_t<int>, int>);
  std::printf("type_identity %d\n", (int) std::is_same_v<std::type_identity_t<const int>, const int>);
  std::printf("bounded %d %d %d\n", (int) std::is_bounded_array_v<int[3]>, (int) std::is_unbounded_array_v<int[]>,
              (int) std::is_bounded_array_v<int[]>);
  std::printf("remove_cvref %d\n", (int) std::is_same_v<std::remove_cvref_t<const int &>, int>);
  std::vector<int> sh{1, 2, 3, 4, 5};
  std::shift_left(sh.begin(), sh.end(), 2);
  std::printf("shift_left %d %d %d\n", sh[0], sh[1], sh[2]);
  std::vector<int> sr{1, 2, 3, 4, 5};
  std::shift_right(sr.begin(), sr.end(), 2);
  std::printf("shift_right %d %d %d\n", sr[2], sr[3], sr[4]);
  auto ow = std::make_unique_for_overwrite<int[]>(3);
  ow[0] = 11;
  auto sp = std::make_shared<int[]>(4, 6);
  auto sq = std::make_shared<int[3]>();
  std::printf("arrays %d %d %d %d\n", ow[0], sp[3], sq[2], (int) std::is_same_v<decltype(sp)::element_type, int>);
  std::string s = "hello world";
  std::string_view sv = s;
  std::printf("starts_with %d %d %d %d\n", (int) s.starts_with("hell"), (int) s.ends_with('d'), (int) sv.starts_with("world"),
              (int) sv.ends_with("world"));
  std::list<int> li{1, 2, 1, 3, 1};
  auto removed = li.remove(1);
  auto removed2 = li.remove_if([](int x) { return x > 2; });
  std::printf("remove %zu %zu %zu\n", removed, removed2, li.size());
  std::unordered_map<std::string, int, SHash, SEq> um{{"alpha", 1}, {"beta", 2}};
  std::printf("lookup %d %zu %d\n", um.find(std::string_view("beta"))->second, um.count("gamma"),
              (int) um.contains(std::string_view("alpha")));
  std::printf("bit %d %d %d %u\n", std::popcount(0xF0u), std::countl_zero(1u), (int) std::has_single_bit(64u), std::bit_ceil(5u));
  auto add = std::bind_front([](int a, int b, int c) { return a * 100 + b * 10 + c; }, 1, 2);
  std::printf("bind_front %d\n", add(3));
  std::printf("identity %d\n", std::identity{}(7));
  std::printf("is_constant_evaluated %d\n", (int) std::is_constant_evaluated());
}
