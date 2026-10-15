// Time zones (libc++'s experimental part, -fexperimental-library): a zone found by name, a time point in it, its
// offset and abbreviation, and the database's version.
#include <chrono>
#include <cstdio>
#include <string>
int main() {
  using namespace std::chrono;
  const time_zone *utc = locate_zone("UTC");
  const time_zone *ny = locate_zone("America/New_York");
  sys_seconds t = sys_days{year{2024} / January / 15} + hours{12};
  sys_info a = ny->get_info(t);
  sys_seconds s = sys_days{year{2024} / July / 15} + hours{12};
  sys_info b = ny->get_info(s);
  std::printf("%s %s\n", std::string(utc->name()).c_str(), std::string(ny->name()).c_str());
  std::printf("%lld %s %lld %s\n", (long long) a.offset.count(), a.abbrev.c_str(), (long long) b.offset.count(), b.abbrev.c_str());
  local_seconds l = ny->to_local(t);
  std::printf("%lld\n", (long long) (l.time_since_epoch() - t.time_since_epoch()).count());
  return 0;
}
