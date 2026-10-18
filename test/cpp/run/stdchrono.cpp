// <chrono>'s durations, their arithmetic and conversions, the clocks and their time points, the literals `1500ms', `2s', `3us'
// (0.179: `3us' was the literal `3u' and the suffix `s', three seconds, where it is three microseconds)
#include <chrono>
#include <cstdio>
using namespace std::chrono_literals;
int main() {
  auto d = 1500ms + 2s;
  std::printf("%lld %lld\n", (long long)d.count(), (long long)std::chrono::duration_cast<std::chrono::seconds>(d).count());
  std::chrono::minutes m(90);
  std::chrono::hours h = std::chrono::duration_cast<std::chrono::hours>(m);
  std::printf("%lld %lld\n", (long long)m.count(), (long long)h.count());
  auto t0 = std::chrono::steady_clock::now();
  auto t1 = std::chrono::steady_clock::now();
  std::printf("%d %d\n", (int)(t1 >= t0), (int)((t1 - t0) >= std::chrono::nanoseconds(0)));
  std::chrono::duration<double> fd(2.5);
  std::printf("%.1f %d\n", fd.count(), (int)(std::chrono::duration_cast<std::chrono::milliseconds>(fd).count()));
  std::chrono::system_clock::time_point tp{};
  tp += 1h;
  std::printf("%lld\n", (long long)std::chrono::duration_cast<std::chrono::minutes>(tp.time_since_epoch()).count());
  auto s = std::chrono::seconds(7);
  std::printf("%lld %lld %lld\n", (long long)(s * 3).count(), (long long)(s / 2).count(), (long long)(s % 4).count());
  std::printf("%lld %lld\n", (long long)(std::chrono::seconds(10) / std::chrono::seconds(3)), (long long)(90min % 1h).count());
  std::printf("%d %d %d\n", (int)(1s == 1000ms), (int)(2min > 119s), (int)(3us < 2ms));
  auto x = std::chrono::milliseconds(-2500);
  std::printf("%lld %lld %lld %lld\n", (long long)std::chrono::floor<std::chrono::seconds>(x).count(),
              (long long)std::chrono::ceil<std::chrono::seconds>(x).count(), (long long)std::chrono::round<std::chrono::seconds>(x).count(),
              (long long)std::chrono::abs(x).count());
  auto now = std::chrono::system_clock::now();
  std::time_t tt = std::chrono::system_clock::to_time_t(now);
  auto back = std::chrono::system_clock::from_time_t(tt);
  std::printf("%d\n", (int)(now - back < 1s));
  auto tq = std::chrono::time_point_cast<std::chrono::seconds>(tp + 1500ms);
  std::printf("%lld\n", (long long)tq.time_since_epoch().count());
  std::chrono::duration<long long, std::ratio<1, 3>> third(4);
  std::printf("%.3f\n", std::chrono::duration<double>(third).count());
  std::printf("%lld %lld\n", (long long)std::chrono::nanoseconds(1us).count(), (long long)std::chrono::microseconds(5ms).count());
  using C = std::common_type_t<std::chrono::seconds, std::chrono::milliseconds>;
  std::printf("%lld\n", (long long)C(2s + 5ms).count());
  std::printf("%d\n", (int)std::chrono::treat_as_floating_point_v<double>);
  return 0;
}
