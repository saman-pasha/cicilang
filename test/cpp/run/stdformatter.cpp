// a formatter the program specializes for its own class (C++20): parse and format templates over the context
#include <cstdio>
#include <format>
#include <string>
struct Point { int x, y; };
template <> struct std::formatter<Point> {
  template <class ParseContext> constexpr auto parse(ParseContext &ctx) { return ctx.begin(); }
  template <class FormatContext> auto format(const Point &p, FormatContext &ctx) const { return std::format_to(ctx.out(), "({}, {})", p.x, p.y); }
};
int main() {
  Point p{3, -4};
  std::string s = std::format("p = {}", p);
  std::printf("%s\n", s.c_str());
  return 0;
}
