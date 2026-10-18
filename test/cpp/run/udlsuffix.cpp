// an integer literal's tail that is no integer suffix is its ud-suffix ([lex.ext]/1; 0.179): `3us', `0x10us', `0b11us', `017us' are
// microseconds, the exact `i', `il' and `if' <complex>'s; and `3ll' a long long, `3ull' an unsigned long long, `3uz' a size_t
#include <chrono>
#include <complex>
#include <cstdio>
#include <typeinfo>
using namespace std::chrono_literals;
using namespace std::complex_literals;
struct UL { unsigned long long v; };
UL operator""_ux(unsigned long long v) { return {v * 2}; }
UL operator""_uz(unsigned long long v) { return {v * 3}; }
int main() {
  auto a = 3us;  auto b = 0x10us; auto c = 0b11us; auto d = 017us;
  std::printf("%lld %lld %lld %lld\n", (long long)a.count(), (long long)b.count(), (long long)c.count(), (long long)d.count());
  auto e = 3i; auto f = 3il; auto g = 3if;
  std::printf("%s %s %s\n", typeid(e).name(), typeid(f).name(), typeid(g).name());
  std::printf("%llu %llu\n", (5_ux).v, (7_uz).v);
  auto h = 3u; auto k = 3ull; auto m = 3uz;
  std::printf("%s %s %s\n", typeid(h).name(), typeid(k).name(), typeid(m).name());
  return 0;
}
