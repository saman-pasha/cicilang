#include <cstdio>
#include <expected>
#include <string>
// std::expected (C++23)
std::expected<int, std::string> parse(const char *s) {
  if (s[0] >= '0' && s[0] <= '9') return s[0] - '0';
  return std::unexpected(std::string("bad: ") + s);
}
int main() {
  auto a = parse("7");
  auto b = parse("x");
  std::printf("%d %d %d\n", (int) a.has_value(), *a, (int) b.has_value());
  std::printf("%s\n", b.error().c_str());
  std::printf("%d %d\n", a.value_or(0), b.value_or(-1));
  auto c = a.transform([](int v) { return v * 3; });
  std::printf("%d\n", *c);
  auto d = b.or_else([](const std::string &e) -> std::expected<int, std::string> { return (int) e.size(); });
  std::printf("%d\n", *d);
  std::expected<void, int> e;
  std::printf("%d\n", (int) e.has_value());
  return 0;
}
