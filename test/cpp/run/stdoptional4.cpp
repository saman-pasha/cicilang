// C++23 optional's transform to a class, and_then over a conditional, or_else
#include <optional>
#include <string>
#include <cstdio>
int main() {
  std::optional<int> o = 3, e;
  auto s = o.transform([](int x) { return std::string(x, 'a'); });
  auto f = e.transform([](int x) { return std::string(x, 'b'); });
  auto h = o.and_then([](int x) { return x > 2 ? std::optional<int>(x * 2) : std::nullopt; });
  auto g = e.or_else([] { return std::optional<int>(7); });
  std::printf("%s %d %d %d\n", s->c_str(), (int) f.has_value(), *h, *g);
  return 0;
}
