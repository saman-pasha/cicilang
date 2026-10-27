// <charconv> after <string> and <variant> (0.218): each read keys apart only the names that collide in it, so `__traits' is
// bare in <string>'s read (std::__variant_detail's) and in <charconv>'s (std::__itoa's), and the first header's answered both
// -- std::from_chars was refused, `no_member_type('__traits.unsigned', type)'; `__itoa::__traits<_Tp>' takes <charconv>'s now
#include <string>
#include <variant>
#include <charconv>
#include <cstdio>
int main() {
  char buf[32];
  auto t = std::to_chars(buf, buf + sizeof buf, 255u, 16);
  *t.ptr = 0;
  long l = 0;
  const char *s = "-9000000000";
  std::from_chars(s, s + 11, l);
  std::variant<int, std::string> v = std::string("x");
  std::printf("%s %ld %d %s\n", buf, l, (int)v.index(), std::get<std::string>(v).c_str());
  return 0;
}
