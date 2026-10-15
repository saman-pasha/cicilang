// std::format OF __int128 (C++20, 0.129): the 128-bit integer arguments of libc++'s format, which held an __int128_t member
// that nothing typed before 0.117 (the reason C++ had no __SIZEOF_INT128__).
#include <cstdio>
#include <format>
#include <limits>
#include <string>

int main() {
  __int128 mx = std::numeric_limits<__int128>::max();
  unsigned __int128 umx = std::numeric_limits<unsigned __int128>::max();
  __int128 neg = -((__int128)1 << 100) - 7;
  std::string a = std::format("{} {:x} {}", mx, umx, neg);
  std::printf("%s\n", a.c_str());
  std::string b = std::format("[{:>45}] [{:#b}] [{:+d}]", neg, (__int128)5, (unsigned __int128)42);
  std::printf("%s\n", b.c_str());
  std::printf("%s\n", std::format("{} {}", 7, (__int128)8).c_str());
  return 0;
}
