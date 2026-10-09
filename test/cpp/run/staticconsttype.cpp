// a static const keeps its declared type where it stands in an expression: a negative long long through printf's %lld, an unsigned
// that wraps, a char and a short (libc++'s ratio<-1, 2>::num); the template form folds a template argument into one
#include <cstdio>
struct A { static const unsigned u = 4; static const long long v = -3; static constexpr long long w = -(1LL << 40); static const unsigned char c = 200; static const short s = -5; };
template <long long N> struct Val { static const long long v = N; };
long long g = -7;
int main() {
  std::printf("%lld %lld %d %d\n", A::v, A::w, A::c, A::s);
  std::printf("%lld %lld\n", Val<-3>::v, Val<(-(10)) / 3>::v);
  std::printf("%lld %u %d\n", g, (A::u - 5u) > 100u ? 1u : 0u, (int)(A::c + 100));
  return 0;
}
