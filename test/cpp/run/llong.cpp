// `3ll' is a long long and `3ull' an unsigned long long ([lex.icon]/3): overloads, templates, decltype, typeid, a null pointer
#include <cstdio>
#include <string>
#include <typeinfo>
#include <type_traits>
#include <algorithm>
int f(long) { return 1; }
int f(long long) { return 2; }
int f(unsigned long) { return 3; }
int f(unsigned long long) { return 4; }
template <class T> const char *name() { return "other"; }
template <> const char *name<long>() { return "long"; }
template <> const char *name<long long>() { return "long long"; }
template <> const char *name<unsigned long long>() { return "unsigned long long"; }
template <class T> const char *of(T) { return name<T>(); }
template <long long N> struct W { static constexpr long long v = N * 2; };
int *gp = 0ll;
int main() {
  std::printf("%d %d %d %d %d %d\n", f(3l), f(3ll), f(3ul), f(3ull), f(0x10LL), f(07ULL));
  std::printf("%s %s %s\n", of(3ll), of(3ull), of(3l));
  std::printf("%d %d\n", (int) std::is_same_v<decltype(3ll), long long>, (int) std::is_same_v<decltype(3uLL), unsigned long long>);
  std::printf("%s %s\n", typeid(3ll).name(), typeid(3ull).name());
  long long x = 7; std::printf("%lld %lld\n", std::max(3ll, x), std::min(x, 9LL));
  std::printf("%s %s\n", std::to_string(1ll << 40).c_str(), std::to_string(18446744073709551615ull).c_str());
  std::printf("%lld %d\n", W<21ll>::v, gp == nullptr);
  int *p = 0LL; std::printf("%d\n", p == nullptr);
  return 0;
}
