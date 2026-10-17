// A USING OF A HEADER NAMESPACE DEEPER THAN std (0.160): its keyed names are the ones a bare call finds, the outer ones where the key's refuse
#include <chrono>
#include <cmath>
#include <cstdio>
using namespace std::chrono;
static long long f() {
  auto d = milliseconds(1700);
  auto s = floor<seconds>(d);
  auto c = ceil<seconds>(d);
  auto r = round<seconds>(d);
  auto a = abs(milliseconds(-3));
  return s.count() * 1000 + c.count() * 100 + r.count() * 10 + a.count();
}
int main() {
  double x = floor(2.7);
  std::printf("%lld %.1f %d\n", f(), x, (int) std::abs(-4));
  {
    using std::chrono::duration_cast;
    std::printf("%lld\n", (long long) duration_cast<seconds>(minutes(2)).count());
  }
  return 0;
}
