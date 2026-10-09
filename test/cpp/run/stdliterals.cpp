// the literal operators of libc++: "text"s (std::string) and "text"sv (std::string_view), through the inline namespaces
// std::literals::string_literals and string_view_literals
#include <string>
#include <string_view>
#include <cstdio>
using namespace std::string_literals;
using namespace std::string_view_literals;
int main() {
  auto s = "hello"s;
  auto v = "world"sv;
  s += " and "s + std::string("more");
  std::printf("%s %zu %.*s %zu\n", s.c_str(), s.size(), (int)v.size(), v.data(), v.size());
  std::string t = "a\0b"s;
  std::printf("%zu %d\n", t.size(), (int)(t == "a\0b"s));
  return 0;
}
