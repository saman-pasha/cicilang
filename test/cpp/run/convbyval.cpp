// a converting constructor's temporary handed to a by-value parameter IS the parameter: made once, destroyed once
#include <cstdio>
struct T { int v; static int made, gone; T(int x) : v(x) { made++; } T(const T &o) : v(o.v) { made++; } ~T() { gone++; } };
int T::made = 0, T::gone = 0;
int g(T t) { return t.v; }
int h(const T &t) { return t.v * 3; }
struct S { int m(T t) { return t.v - 1; } };
int main() {
  int a = g(9); std::printf("%d %d %d\n", a, T::made, T::gone);
  int b = h(4); std::printf("%d %d %d\n", b, T::made, T::gone);
  S s; int c = s.m(6); std::printf("%d %d %d\n", c, T::made, T::gone);
  return 0;
}
