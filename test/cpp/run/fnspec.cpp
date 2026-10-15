// EXPLICIT SPECIALIZATIONS OF FUNCTION TEMPLATES (0.129): no candidate of their own; the instance the chosen template makes for
// those arguments IS the specialization. Every one was ignored: `template <> int f(unsigned long, int)' tied with the primary and
// the primary, declared first, won; `template <> int f<char>(char, int)' was read by nothing.
#include <cstdio>
#include <string>

template <class T> int f(T, int) { return 1; }
template <> int f(unsigned long, int) { return 2; }          // the arguments deduced from the function type
template <> int f<char>(char, int) { return 3; }             // the arguments written

template <class T> T zero() { return T(); }                  // T only in the result: the written argument decides
template <> int zero<int>() { return 42; }

template <class T> struct tag {};
template <class T> inline int g(T, tag<T>) { return 10; }
template <> inline int g<double>(double, tag<double>) { return 20; }

template <class T> int h(T);                                 // the primary declared, the specialization defined after the use
template <> int h<int>(int x);

namespace ns {
template <class T> const char *name(const T &) { return "other"; }
template <> const char *name(const std::string &) { return "string"; }
template <> const char *name<int>(const int &) { return "int"; }
}

template <class T> int over(T) { return 100; }               // two templates: the more specialized chosen, then ITS specialization
template <class T> int over(T *) { return 200; }
template <> int over<int>(int *) { return 300; }             // specializes over(T *) with T = int
template <> int over<int>(int) { return 400; }               // specializes over(T) with T = int

int main() {
  std::printf("%d %d %d %d\n", f(1, 0), f(1UL, 0), f('a', 0), f(2.5, 0));
  std::printf("%d %d %g\n", zero<int>(), (int)zero<long>(), zero<double>());
  std::printf("%d %d\n", g(1, tag<int>()), g(2.0, tag<double>()));
  std::printf("%d %d\n", h(5), h(6L));
  std::string s = "x";
  std::printf("%s %s %s\n", ns::name(s), ns::name(7), ns::name(1.5));
  int i = 0;
  double d = 0;
  std::printf("%d %d %d %d\n", over(i), over(&i), over(d), over(&d));
  return 0;
}

template <> int h<int>(int x) { return x * 3; }
template <class T> int h(T x) { return (int)x + 1000; }
