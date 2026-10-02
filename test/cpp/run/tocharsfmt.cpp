// A header's enum in a shipped function's mangled name is a nested name: `std::to_chars(char *, char *, double,
// chars_format)' is `_ZNSt3__18to_charsEPcS0_dNS_12chars_formatE' (0.112)
#include <charconv>
#include <cstdio>
int main() {
  char buf[32];
  auto r = std::to_chars(buf, buf + sizeof buf, 3.25, std::chars_format::fixed);
  *r.ptr = 0;
  std::printf("%s\n", buf);
  auto r2 = std::to_chars(buf, buf + sizeof buf, 1.5f, std::chars_format::scientific, 2);
  *r2.ptr = 0;
  std::printf("%s\n", buf);
  auto r3 = std::to_chars(buf, buf + sizeof buf, 255, 16);
  *r3.ptr = 0;
  std::printf("%s\n", buf);
  auto r4 = std::to_chars(buf, buf + sizeof buf, 0.125);
  *r4.ptr = 0;
  std::printf("%s\n", buf);
  return 0;
}
