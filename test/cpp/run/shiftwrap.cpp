// constant folding of a left shift (it wraps in the promoted type of its left operand: intmax_t(1) << 63 is -2^63, as clang folds it)
// and of the signed wide division that follows, as a template argument and as a static member initializer; libc++'s duration
// conversions (<chrono>'s __no_overflow) decide on exactly this arithmetic
#include <cstdio>
#include <cstdint>
#include <climits>
template <bool B> struct Tag { static const int v = B ? 1 : 0; };
template <long long N> struct Val { static const long long v = N; };
int main() {
  static const intmax_t mx = -((intmax_t(1) << (sizeof(intmax_t) * CHAR_BIT - 1)) + 1);
  std::printf("%d %d %lld\n", Tag<(1 <= mx / 1000)>::v, Tag<(1000 <= mx / 1)>::v, (long long)mx);
  std::printf("%lld\n", Val<(-(10)) / 3>::v);
  std::printf("%lld\n", Val<(-((1LL << 62) + 5)) / 1000>::v);
  std::printf("%lld\n", Val<(-((intmax_t(1) << 62) + 5)) / 1000>::v);
  std::printf("%lld\n", Val<(-((intmax_t(1) << 63) + 1)) / 1000>::v);
  std::printf("%lld\n", Val<((intmax_t(1) << 63) + 1) / 1000>::v);
  std::printf("%lld\n", Val<-((intmax_t(1) << 63) + 1) / 1000>::v);
  std::printf("%lld\n", Val<(9223372036854775807LL) / 1000>::v);
  std::printf("%lld\n", Val<(-9223372036854775807LL) / 1000>::v);
  std::printf("%lld\n", Val<(0 - (-9223372036854775807LL)) / 1000>::v);
  return 0;
}
