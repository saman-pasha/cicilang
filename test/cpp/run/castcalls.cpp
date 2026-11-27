// castcalls.cpp (1.6.26): the forms beside 1.6.26's refusals that C++ takes -- casts between integers, floating values
// and pointers that no rule refuses, qualified calls with their counts, defaults and ellipses, templates of two counts,
// and functions marked unavailable beside the overloads that a call chooses
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cstdarg>
typedef double D;
using P = int *;
namespace n {
int f(int a, int b = 2) { return a * b; }
int sum(int k, ...) { va_list ap; va_start(ap, k); int s = 0; for (int i = 0; i < k; i++) s += va_arg(ap, int); va_end(ap); return s; }
template <class T> int g(T a, int k = 3) { return (int)a * k; }
}
int h(int a) { return a + 1; }
namespace m { using ::h; }
template <class T> int t(T a) { return (int)a; }
template <class T, class U> int t(T a, U b) { return (int)a + (int)b; }
struct S {
  static int g(int a, int b = 1) { return a + b; }
  static int w(int a, ...) { return a; }
  int u() __attribute__((unavailable("gone")));
  int v() { return 7; }
};
int pick(int) __attribute__((unavailable));
int pick(double d) { return (int)(d * 10); }
int main() {
  int x = 7; int *q = &x; double d = 2.75; float fl = 1.5f;
  long a = (long)q; std::uintptr_t b = reinterpret_cast<std::uintptr_t>(q);
  int *r = reinterpret_cast<int *>(b); P s = P(r);
  double e = (double)x; D dg = D(x); int i = static_cast<int>(d); long k = long(fl);
  const int *cq = q; int *mq = const_cast<int *>(cq);
  void *v = (void *)q; int *w = static_cast<int *>(v);
  std::printf("%d %d %d %d %.2f %.2f %d %ld %d\n", a == (long)b, *r, *s, *mq, e, dg, i, k, *w);
  std::printf("%d %d %d %d %d\n", n::f(4), n::f(4, 5), n::sum(3, 1, 2, 3), n::g(2), n::g(2, 4));
  std::printf("%d %d %d %d %d\n", ::h(1), m::h(2), t(1), t(2, 3.5), S::g(5));
  S o;
  std::printf("%d %d %d %d\n", S::g(5, 6), S::w(9, 1, 2), o.v(), pick(1.25));
  std::puts("end");
  return (int)std::strlen("ok");
}
