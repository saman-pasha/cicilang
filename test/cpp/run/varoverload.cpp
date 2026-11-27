// An overload with an ellipsis beside one of the same parameters without it, and overloads declared before their
// definitions (1.6.38; [dcl.fct]/4, [over.load], [over.over]). Each value is clang++'s.
#include <cstdarg>
#include <cstdio>

int f(int a, ...) { va_list ap; va_start(ap, a); int b = va_arg(ap, int); va_end(ap); return a + b + 100; }
int f(int a) { return a + 1; }

int g(int);
int g(int, ...);
int h(int);
int h(double);

int k(double d) { return (int)d; }
int k(double d, ...) { return (int)d + 1000; }
int k(int a, int b) { return a - b; }

struct T {
  int m(int a) { return a + 10; }
  int m(int a, ...) { return a + 20; }
  int o(int a);
  int o(int a, ...);
  static int s(int a) { return a + 30; }
  static int s(int a, ...) { return a + 40; }
  int c(int a) const { return a + 50; }
  int c(int a, ...) const { return a + 60; }
};
int T::o(int a) { return a + 70; }
int T::o(int a, ...) { return a + 80; }

struct U { static int p(int a) { return a + 1; } static int p(double d) { return (int)d + 2; } };
struct V { static int q(int a, ...) { return a + 90; } static int q(int a) { return a + 9; } };
struct X { int c(int a) const { return a + 1; } int c(int a, ...) { return a + 2; } };   // twins only of one constness

int main() {
  int (*pf)(int) = f; int (*qf)(int, ...) = f;
  std::printf("free: %d %d %d %d\n", pf(1), qf(1, 5), f(1, 2), f(3, 4, 5));
  int (*pg)(int) = g; int (*ph)(int) = h; int (*qh)(double) = h;
  std::printf("declared first: %d %d %d %d %d\n", pg(4), g(4, 9), ph(4), qh(2.5), h(2.5));
  int (*pk)(double) = k;
  std::printf("keys apart: %d %d %d\n", pk(2.5), k(2.5, 1, 2), k(9, 4));
  T t; const T &r = t;
  int (T::*pm)(int) = &T::m; int (T::*qm)(int, ...) = &T::m; int (T::*qc)(int, ...) const = &T::c; int (*ps)(int) = &T::s;
  std::printf("members: %d %d %d %d %d %d %d\n", (t.*pm)(1), (t.*qm)(1, 2), t.m(1, 2), r.c(1, 2), (r.*qc)(1, 2), ps(1), T::s(1, 2));
  int (T::*po)(int) = &T::o;
  std::printf("defined out of the class: %d %d %d\n", (t.*po)(1), t.o(1, 2), t.s(1, 2));
  int (*up)(int) = &U::p; int (*ud)(double) = U::p; int (*ue)(double) = &U::p;
  int (*vq)(int) = V::q; int (*wq)(int) = &V::q;
  std::printf("static overloads as values: %d %d %d %d %d %d\n", up(1), ud(1.5), ue(2.5), vq(1), wq(2), V::q(1, 2));
  X x; const X &xk = x;
  std::printf("a const member beside a variadic one: %d %d %d\n", x.c(1), xk.c(1), x.c(1, 2));
  return 0;
}

int g(int a) { return a * 2; }
int g(int a, ...) { return a * 3; }
int h(int a) { return a + 5; }
int h(double d) { return (int)d * 7; }
