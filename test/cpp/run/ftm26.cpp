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
// C++26'S SATURATION ARITHMETIC BY ITS NAMES (1.6.21): the paper that unified them renamed add_sat, sub_sat, mul_sat,
// div_sat and saturate_cast saturating_add, saturating_sub, saturating_mul, saturating_div and saturating_cast --
// libc++ 23's, __cpp_lib_saturation_arithmetic 202603L, where libc++ 22's 202311L has the old names
#if __cpp_lib_saturation_arithmetic >= 202603L
#define ADD_SAT std::saturating_add
#define SUB_SAT std::saturating_sub
#define MUL_SAT std::saturating_mul
#define DIV_SAT std::saturating_div
#define SAT_CAST std::saturating_cast
#else
#define ADD_SAT std::add_sat
#define SUB_SAT std::sub_sat
#define MUL_SAT std::mul_sat
#define DIV_SAT std::div_sat
#define SAT_CAST std::saturate_cast
#endif

int sum(std::span<const int> s) { int t = 0; for (int x : s) t += x; return t; }

int main() {
  std::printf("add_sat %d %d %u\n", ADD_SAT(INT_MAX, 5), ADD_SAT(-5, -INT_MAX), ADD_SAT(4000000000u, 1000000000u));
  std::printf("sub_sat %d %u\n", SUB_SAT(INT_MIN, 1), SUB_SAT(3u, 5u));
  std::printf("mul_sat %d %d\n", MUL_SAT(100000, 100000), MUL_SAT(-100000, 100000));
  std::printf("div_sat %d %d\n", DIV_SAT(INT_MIN, -1), DIV_SAT(7, 2));
  std::printf("saturate_cast %d %d %u\n", (int) SAT_CAST<signed char>(300), (int) SAT_CAST<unsigned char>(-4),
              SAT_CAST<unsigned>(-1L));
  int arr[3] = {4, 5, 6};
  std::span<int> sp(arr);
  std::printf("span_at %d", sp.at(1));
  try { (void) sp.at(3); } catch (const std::out_of_range &) { std::printf(" out_of_range"); }
  std::printf("\n");
#if defined(__cpp_lib_span_initializer_list)
  std::printf("span_il %d\n", sum({1, 2, 3, 4}));
#else
  // libc++ 23 has no span from an initializer_list, nor its feature-test macro (1.6.21): clang++ 23 refuses the braced
  // list, `cannot convert initializer list argument', as cicilang++ does; an array's span prints the same line
  const int il[] = {1, 2, 3, 4};
  std::printf("span_il %d\n", sum(il));
#endif
  std::bitset<6> b(std::string_view("101101"));
  std::printf("bitset_sv %lu\n", b.to_ulong());
  std::printf("ratio %lld %lld\n", (long long) std::ratio_add<std::kilo, std::mega>::num, (long long) std::ratio_divide<std::milli, std::micro>::num);
  std::ofstream f;
  std::printf("native_handle %d\n", (int) std::is_same_v<std::ofstream::native_handle_type, int>);
}
