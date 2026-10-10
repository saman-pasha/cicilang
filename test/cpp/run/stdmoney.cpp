// The money and time facets over the classic "C" locale: put_money and get_money of a long double, put_time of a tm.
#include <cstdio>
#include <ctime>
#include <iomanip>
#include <locale>
#include <sstream>
int main() {
  std::ostringstream o;
  o << std::put_money(12345.0L) << '|' << std::put_money(std::string("678"));
  std::istringstream i("2050");
  long double v = 0;
  i >> std::get_money(v);
  std::tm t{};
  t.tm_year = 126; t.tm_mon = 9; t.tm_mday = 10; t.tm_hour = 18; t.tm_min = 5;
  std::ostringstream ot;
  ot << std::put_time(&t, "%Y-%m-%d %H:%M");
  std::istringstream it("2026-10-10 18:05");
  std::tm u{};
  it >> std::get_time(&u, "%Y-%m-%d %H:%M");
  std::printf("%s %.0Lf %s %d %d\n", o.str().c_str(), v, ot.str().c_str(), u.tm_year + 1900, u.tm_min);
  return 0;
}
