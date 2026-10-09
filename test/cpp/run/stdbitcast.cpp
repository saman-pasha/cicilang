// <bit> (C++20, 0.117): std::bit_cast is `return __builtin_bit_cast(_ToType, __from);' in libc++, and the builtin was `trait_unknown('__builtin_bit_cast')'. It is a
// local of the target type filled by memcpy from a local copy of the operand, the value of a statement expression. A float and an integer, a double,
// a struct, a std::array of bytes; beside them the bit counting and rotating functions of the header
#include <array>
#include <bit>
#include <cstdint>
#include <cstdio>
struct Pair { std::uint16_t a; std::uint16_t b; };
int main() {
  float f = 1.0f;
  std::uint32_t u = std::bit_cast<std::uint32_t>(f);
  std::printf("%08x %d %d\n", u, std::popcount(u), std::countl_zero(u));
  double d = std::bit_cast<double>(std::uint64_t(0x4000000000000000ull));
  std::printf("%g\n", d);
  Pair p = std::bit_cast<Pair>(std::uint32_t(0x00020001u));
  std::printf("%d %d\n", (int)p.a, (int)p.b);
  auto bytes = std::bit_cast<std::array<unsigned char, 4>>(std::uint32_t(0x04030201u));
  std::printf("%d %d %d %d\n", bytes[0], bytes[1], bytes[2], bytes[3]);
  std::printf("%d %d %u %u\n", (int)std::has_single_bit(64u), (int)std::has_single_bit(65u), std::bit_ceil(65u), std::bit_floor(65u));
  std::printf("%u %u %d %d\n", std::rotl(0x80000001u, 1), std::rotr(0x80000001u, 1), std::countr_zero(8u), std::bit_width(255u));
  return 0;
}
