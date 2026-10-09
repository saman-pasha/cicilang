// std::byte (C++17, 0.117): `enum class byte : unsigned char' in namespace std, which a library function template names among
// its arguments the moment a vector holds one. The Itanium mangler took any class typedef that targets an enum for the enum's
// holder -- `value_type' of `__split_buffer<std::byte, ...>' -- and walked the chain it built for ever (4 GB in ten seconds).
// A vector of bytes, the operators of <cstddef> and to_integer.
#include <cstddef>
#include <cstdio>
#include <vector>
int main() {
  std::vector<std::byte> v;
  v.push_back(std::byte{7});
  v.push_back(std::byte{9});
  v.push_back(static_cast<std::byte>(0xF0));
  int s = 0;
  for (auto b : v) s += (int)b;
  std::printf("%zu %d\n", v.size(), s);
  std::byte a{0x0F}, b{0x3C};
  std::printf("%d %d %d %d\n", (int)(a | b), (int)(a & b), (int)(a ^ b), (int)(~a));
  std::printf("%d %d %d\n", std::to_integer<int>(a << 2), std::to_integer<int>(b >> 1), (int)sizeof(std::byte));
  a |= b;
  a <<= 1;
  std::printf("%d\n", std::to_integer<int>(a));
  return 0;
}
