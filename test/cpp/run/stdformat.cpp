// std::format on libc++ 18 (C++20, 0.112): integers, strings, widths, alignment, fill, hex, a double with a
// precision, a char, a bool, a std::string argument, positional arguments and std::format_to
#include <cstdio>
#include <format>
#include <iterator>
#include <string>
int main() {
  std::string s = std::format("{} and {}", 2, 3);
  std::printf("%s\n", s.c_str());
  std::printf("[%s]\n", std::format("{:d} {:x} {:X} {:o} {:b}", 42, 255, 255, 8, 5).c_str());
  std::printf("[%s]\n", std::format("{:>6}|{:<6}|{:^6}", 1, 2, 3).c_str());
  std::printf("[%s]\n", std::format("{:*>5} {:05}", 7, -42).c_str());
  std::printf("[%s]\n", std::format("{:.2f} {}", 3.14159, 2.5).c_str());
  std::printf("[%s]\n", std::format("{} {} {}", 'c', true, false).c_str());
  std::string name = "world";
  std::printf("[%s]\n", std::format("hello, {}!", name).c_str());
  std::printf("[%s]\n", std::format("{1} {0} {1}", "a", "b").c_str());
  std::string out;
  std::format_to(std::back_inserter(out), "{}-{}", 10, "x");
  std::printf("[%s]\n", out.c_str());
  return 0;
}
