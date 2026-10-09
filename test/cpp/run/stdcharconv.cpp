// <charconv> (0.117): std::from_chars of int, long, unsigned (base 10 and 16), an invalid string, a value out of range for an unsigned char, and std::to_chars
// of ints. Four defects stood between libc++'s from_chars and a run: `using typename __traits_base<_Tp>::type;' (a type brought from a base) left `type &'
// undeclared; `std::errc()' (an enum value-initialized) was undeclared; `__pow() + 1' added to a loaded [10 x i32] (a call returning a reference to an
// array); and `__mul_overflowed(unsigned char, _Tp, unsigned char &)' was chosen for a uint32_t lvalue and wrote one byte of it -- the value stored was 0
#include <charconv>
#include <cstdio>
#include <cstring>
#include <system_error>
int main() {
  const char *s = "12345 rest";
  int v = 0;
  auto r = std::from_chars(s, s + std::strlen(s), v);
  std::printf("%d %d %d\n", v, (int)(r.ptr - s), (int)(r.ec == std::errc()));
  const char *t = "-77";
  long w = 0;
  auto q = std::from_chars(t, t + 3, w);
  std::printf("%ld %d\n", w, (int)(q.ptr - t));
  unsigned u = 0;
  auto z = std::from_chars("ff", "ff" + 2, u, 16);
  std::printf("%u %d\n", u, (int)(z.ec == std::errc()));
  int bad = 5;
  auto b = std::from_chars("abc", "abc" + 3, bad);
  std::printf("%d %d\n", bad, (int)(b.ec == std::errc::invalid_argument));
  unsigned char small = 0;
  auto o = std::from_chars("300", "300" + 3, small);
  std::printf("%d\n", (int)(o.ec == std::errc::result_out_of_range));
  char buf[32];
  auto tr = std::to_chars(buf, buf + sizeof buf, 9876);
  *tr.ptr = 0;
  std::printf("%s\n", buf);
  auto th = std::to_chars(buf, buf + sizeof buf, 255, 16);
  *th.ptr = 0;
  std::printf("%s\n", buf);
  return 0;
}
