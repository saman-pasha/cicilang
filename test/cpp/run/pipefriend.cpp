// a range adaptor's shape: a closure held as a data member, called through the object (c.f(x)), and the pipe a hidden friend operator| template
#include <cstdio>
struct Vec { int d[4]; };
template <class F> struct closure {
  F f;
  template <class R> friend int operator|(R &r, closure c) { int s = 0; for (int i = 0; i < 4; i++) if (c.f(r.d[i])) s += r.d[i]; return s; }
};
struct maker { template <class F> closure<F> operator()(F f) const { return closure<F>{f}; } };
inline constexpr maker keep{};
int main() {
  Vec v{{1, 2, 3, 4}};
  int s = v | keep([](int x) { return x % 2 == 0; });
  std::printf("%d\n", s);
  return 0;
}
