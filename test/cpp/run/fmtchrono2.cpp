// std::format of chrono time points, calendar types and hh_mm_ss (C++20, 0.137).
#include <chrono>
#include <cstdio>
#include <format>
#include <string>
int main() {
  using namespace std::chrono;
  sys_seconds t{seconds(86400 * 365 + 3725)};
  year_month_day d{year(2024), month(2), day(29)};
  std::string a = std::format("{:%Y-%m-%d %H:%M:%S}", t);
  std::string b = std::format("{} {} {}", d, weekday(3), month(11));
  std::string c = std::format("{}", hh_mm_ss<seconds>(seconds(3725)));
  std::printf("%s | %s | %s\n", a.c_str(), b.c_str(), c.c_str());
  return 0;
}
