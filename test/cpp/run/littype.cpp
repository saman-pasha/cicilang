#include <chrono>
#include <cstdio>
#include <type_traits>
// an integer literal is the first type that holds its value ([lex.icon]/3): a decimal one past INT_MAX a long, a hex,
// octal or binary one past INT_MAX that an unsigned int holds an unsigned int -- in overloads, deduction, decltype, a
// template's argument, a std::chrono duration built from one, and a switch over a long
void f(int) { std::puts("f(int)"); }
void f(unsigned) { std::puts("f(unsigned)"); }
void f(long) { std::puts("f(long)"); }
void f(unsigned long) { std::puts("f(unsigned long)"); }
template <class T> const char *name(const T &) {
  return std::is_same_v<T, int> ? "int" : std::is_same_v<T, unsigned> ? "unsigned" : std::is_same_v<T, long> ? "long"
       : std::is_same_v<T, unsigned long> ? "unsigned long" : std::is_same_v<T, long long> ? "long long"
       : std::is_same_v<T, unsigned long long> ? "unsigned long long" : "other";
}
template <auto N> struct V { static constexpr auto v = N; };
int main() {
  f(2147483647); f(2147483648); f(0x7FFFFFFF); f(0x80000000); f(0xFFFFFFFF); f(0x100000000); f(4294967295u); f(4294967296u);
  std::printf("%s %s %s %s\n", name(2147483648), name(0x80000000), name(037777777777), name(0b10000000000000000000000000000000));
  std::printf("%s %s %s\n", name(4294967296u), name(0xFFFFFFFFFFFFFFFF), name(0xFFFFFFFFFFFFFFFFll));
  static_assert(std::is_same_v<decltype(2147483648), long>);
  static_assert(std::is_same_v<decltype(0x80000000), unsigned>);
  static_assert(std::is_same_v<decltype(V<0x80000000>::v), const unsigned>);
  std::printf("%zu %zu %zu\n", sizeof(V<2147483648>::v), sizeof(V<0x80000000>::v), sizeof(0xFFFFFFFF));
  auto d = std::chrono::nanoseconds(2500000000);
  std::printf("%lld %lld\n", (long long) std::chrono::duration_cast<std::chrono::seconds>(d).count(), (long long) d.count());
  std::printf("%d %u %ld\n", 0x80000000 > -1 ? 1 : 0, ~0x80000000, ~2147483648);
  long x = 0x100000001L;
  switch (x) { case 1: std::puts("one"); break; case 0x100000001L: std::puts("big"); break; default: std::puts("none"); }
  return 0;
}
