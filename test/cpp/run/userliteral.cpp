// user-defined literals (C++11 [lex.ext]): an integer, a floating, a string and a character literal with a suffix of the
// program's own, in a namespace and overloaded by the literal's kind, called as `5_km', `1.5_twice', `"hello"_len', `'a'_up'
#include <cstdio>
#include <cstddef>
struct Len { size_t n; char first; };
long long operator"" _km(unsigned long long v) { return (long long)v * 1000; }
long double operator"" _twice(long double v) { return v * 2; }
Len operator"" _len(const char *p, size_t n) { return Len{n, p[0]}; }
char operator"" _up(char c) { return c - 32; }
namespace units {
  double operator"" _m(long double v) { return (double)v; }
  int operator"" _m(unsigned long long v) { return (int)v * 10; }
  constexpr unsigned operator"" _kib(unsigned long long v) { return (unsigned)v * 1024u; }
}
struct Money { long cents; };
Money operator"" _usd(long double v) { return Money{(long)(v * 100 + 0.5L)}; }
int main() {
  using namespace units;
  long long a = 5_km;
  long double b = 1.5_twice;
  Len s = "hello"_len;
  char c = 'a'_up;
  double d = 2.5_m;
  int e = 3_m;
  constexpr unsigned k = 4_kib;
  Money m = 12.34_usd;
  std::printf("%lld %.1Lf %zu %c %c %.1f %d %u %ld\n", a, b, s.n, s.first, c, d, e, k, m.cents);
  std::printf("%lld\n", 2_km + 0x10_km + 010_km);
  return 0;
}
