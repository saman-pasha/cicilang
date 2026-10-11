// std::format of chrono durations (C++20).
#include <chrono>
#include <cstdio>
#include <format>
#include <string>
int main() {
  using namespace std::chrono;
  std::string a = std::format("{}", seconds(5));
  std::string b = std::format("{} {}", milliseconds(250), minutes(3));
  std::string c = std::format("{:%H:%M:%S}", seconds(3725));
  std::printf("%s | %s | %s\n", a.c_str(), b.c_str(), c.c_str());
  return 0;
}
