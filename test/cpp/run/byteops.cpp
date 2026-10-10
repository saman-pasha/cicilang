// The operators of a SCOPED enum are the header's (0.127): std::byte has no built-in ~, <<, |=, and its enum promoted to
// int gave ~15, -16, where libc++'s operator~(byte) gives the byte 0xF0.
#include <cstddef>
#include <cstdio>
int main() {
  std::byte a{0x0F}, b{0xF0};
  std::printf("%d %d\n", (int)(~a), std::to_integer<int>(~a));
  std::printf("%d %d\n", (int)(b << 1), (int)(b >> 3));
  b <<= 1;
  a |= std::byte{0x30};
  std::printf("%d %d %d\n", (int)b, (int)a, (int)(a & b));
  return 0;
}
