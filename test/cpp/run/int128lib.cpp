// __int128 IN C++ (0.129): libc++ in its int128 configuration (__SIZEOF_INT128__ predefined in C++ as in C) -- the traits,
// numeric_limits, to_chars and from_chars in 128 bits, hash. The limits are folded constants past 64 bits, typed __int128 now
// (they were an unsigned long, cut to an i64), and to_chars of a small value takes libc++'s 64-bit road through the explicit
// specialization __to_chars_itoa(char *, char *, __uint128_t, false_type).
#include <charconv>
#include <cstdio>
#include <cstring>
#include <functional>
#include <limits>
#include <type_traits>

int main() {
  static_assert(std::is_integral_v<__int128>);
  static_assert(std::is_signed_v<__int128>);
  static_assert(std::is_unsigned_v<unsigned __int128>);
  static_assert(std::is_same_v<std::make_unsigned_t<__int128>, unsigned __int128>);
  static_assert(std::is_same_v<std::make_signed_t<unsigned __int128>, __int128>);
  __int128 mx = std::numeric_limits<__int128>::max();
  __int128 mn = std::numeric_limits<__int128>::min();
  unsigned __int128 umx = std::numeric_limits<unsigned __int128>::max();
  std::printf("%d %d %d\n", std::numeric_limits<__int128>::digits, std::numeric_limits<unsigned __int128>::digits10,
              (int)std::numeric_limits<__int128>::is_signed);
  char buf[64];
  auto r = std::to_chars(buf, buf + 64, mx);
  *r.ptr = 0;
  std::printf("%s\n", buf);
  r = std::to_chars(buf, buf + 64, mn);
  *r.ptr = 0;
  std::printf("%s\n", buf);
  r = std::to_chars(buf, buf + 64, umx, 16);
  *r.ptr = 0;
  std::printf("%s\n", buf);
  const char *s = "-12345678901234567890123456789";
  __int128 v = 0;
  auto fr = std::from_chars(s, s + std::strlen(s), v);
  std::printf("%d %lld %lld\n", (int)(fr.ec == std::errc()), (long long)(v / 1000000000000000000LL), (long long)(v % 1000000000000000000LL));
  std::printf("%d\n", (int)(std::hash<__int128>{}(42) == std::hash<__int128>{}(42)));
  return 0;
}
