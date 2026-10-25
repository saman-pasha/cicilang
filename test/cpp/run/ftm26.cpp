// libc++'s C++26 facilities by their feature-test macros (0.206): the saturation arithmetic and saturate_cast, span's
// at and a span from a braced list, bitset from a string_view, the SI ratios, and a file stream's native_handle_type.
#include <bitset>
#include <climits>
#include <cstdio>
#include <fstream>
#include <functional>
#include <numeric>
#include <ratio>
#include <span>
#include <stdexcept>
#include <string_view>
#include <type_traits>

int sum(std::span<const int> s) { int t = 0; for (int x : s) t += x; return t; }

int main() {
  std::printf("add_sat %d %d %u\n", std::add_sat(INT_MAX, 5), std::add_sat(-5, -INT_MAX), std::add_sat(4000000000u, 1000000000u));
  std::printf("sub_sat %d %u\n", std::sub_sat(INT_MIN, 1), std::sub_sat(3u, 5u));
  std::printf("mul_sat %d %d\n", std::mul_sat(100000, 100000), std::mul_sat(-100000, 100000));
  std::printf("div_sat %d %d\n", std::div_sat(INT_MIN, -1), std::div_sat(7, 2));
  std::printf("saturate_cast %d %d %u\n", (int) std::saturate_cast<signed char>(300), (int) std::saturate_cast<unsigned char>(-4),
              std::saturate_cast<unsigned>(-1L));
  int arr[3] = {4, 5, 6};
  std::span<int> sp(arr);
  std::printf("span_at %d", sp.at(1));
  try { (void) sp.at(3); } catch (const std::out_of_range &) { std::printf(" out_of_range"); }
  std::printf("\n");
  std::printf("span_il %d\n", sum({1, 2, 3, 4}));
  std::bitset<6> b(std::string_view("101101"));
  std::printf("bitset_sv %lu\n", b.to_ulong());
  std::printf("ratio %lld %lld\n", (long long) std::ratio_add<std::kilo, std::mega>::num, (long long) std::ratio_divide<std::milli, std::micro>::num);
  std::ofstream f;
  std::printf("native_handle %d\n", (int) std::is_same_v<std::ofstream::native_handle_type, int>);
}
