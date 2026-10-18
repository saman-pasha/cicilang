// std::source_location (C++20): libc++'s current() reads __builtin_source_location() through its default argument, the
// place of the call that uses that default (the outermost one), in the function's signature as clang spells it
#include <source_location>
#include <cstdio>
#include <cstring>
static const char *base(const char *p) { const char *s = std::strrchr(p, '/'); return s ? s + 1 : p; }
#define SHOW(l) std::printf("%s:%u:%u %s\n", base((l).file_name()), (unsigned) (l).line(), (unsigned) (l).column(), (l).function_name())
void log(const char *msg, std::source_location l = std::source_location::current()) { std::printf("%s: ", msg); SHOW(l); }
struct K {
  void f() { log("in method"); }
  template <class T> static T g(T x) { log("in template"); return x; }
};
namespace ns { int h(int a, double) { auto l = std::source_location::current(); SHOW(l); return a; } }
struct Lg {
  std::source_location s;
  Lg(int, std::source_location l = std::source_location::current()) : s(l) {}
  void log(std::source_location l = std::source_location::current()) const { SHOW(l); }
};
template <class T> T twice(T x, std::source_location l = std::source_location::current()) { SHOW(l); return x + x; }
int main() {
  log("hello");
    log("indented");
  K k{}; k.f();
  K::g(2.5);
  ns::h(1, 2.0);
  auto here = std::source_location::current();
  SHOW(here);
  std::source_location empty;
  std::printf("%u %u [%s] [%s]\n", (unsigned) empty.line(), (unsigned) empty.column(), empty.file_name(), empty.function_name());
  [] { log("lambda"); }();
  Lg a(1); SHOW(a.s);
  log(
    "split");
  int r =
     ns::h(4, 0.5);
  std::printf("%d %d\n", r, twice(21));
  return 0;
}
