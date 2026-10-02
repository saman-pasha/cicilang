// std::vformat over std::make_format_args, std::formatted_size and std::format_to_n (C++20)
#include <cstdio>
#include <format>
#include <string>
int main() {
  int a = 7; double b = 2.5;
  std::string s = std::vformat("{} and {:.2f}", std::make_format_args(a, b));
  std::printf("%s\n", s.c_str());
  std::printf("%zu\n", std::formatted_size("{:>6}", 42));
  char buf[8] = {};
  auto r = std::format_to_n(buf, 5, "{}", 1234567);
  std::printf("%.5s %td\n", buf, r.size);
  return 0;
}
