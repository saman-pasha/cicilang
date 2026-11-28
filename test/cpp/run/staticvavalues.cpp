// Static member functions with an ellipsis, named as values (1.6.57): each value is the function's own body with no
// `this', in its class and out of it, through a namespace, a template instance and a derived class, and each call
// through the pointer passes the arguments past the named parameter; of an overload set, the target's type chooses
#include <cstdio>
#include <cstdarg>
struct S {
  static int sum(int n, ...) { va_list ap; va_start(ap, n); int s = 0; for (int i = 0; i < n; i++) s += va_arg(ap, int); va_end(ap); return s + k; }
  static int k;
  static int twice(int n, ...);
};
int S::k = 100;
int S::twice(int n, ...) { va_list ap; va_start(ap, n); int s = 0; for (int i = 0; i < n; i++) s += 2 * va_arg(ap, int); va_end(ap); return s; }
struct D : S { int extra; };
namespace N {
struct T {
  static int base() { return 1000; }
  static int add(int n, ...) { va_list ap; va_start(ap, n); int s = base(); for (int i = 0; i < n; i++) s += va_arg(ap, int); va_end(ap); return s; }
  static int (*getp())(int, ...) { return &add; }
};
}
template <class U> struct W {
  static U pick(int n, ...) { va_list ap; va_start(ap, n); U r = 0; for (int i = 0; i < n; i++) r = va_arg(ap, U); va_end(ap); return r; }
};
static double mean(int n, ...) { va_list ap; va_start(ap, n); double s = 0; for (int i = 0; i < n; i++) s += va_arg(ap, double); va_end(ap); return s / n; }
struct M { static double (*pick)(int, ...); };
double (*M::pick)(int, ...) = mean;
int call(int (*f)(int, ...)) { return f(3, 1, 2, 3); }
struct T2 { static int s(int a) { return a + 30; } static int s(int a, ...) { return a + 40; } };
int main() {
  int (*p)(int, ...) = &S::sum;
  auto q = S::twice;
  std::printf("%d %d %d %d %d\n", p(2, 5, 6), q(2, 5, 6), call(S::sum), call(&S::twice), S::sum(1, 9));
  int (*r)(int, ...) = N::T::getp();
  long (*w)(int, ...) = &W<long>::pick;
  std::printf("%d %d %ld\n", r(2, 3, 4), N::T::add(1, 5), w(3, 7L, 8L, 9L));
  int (*d)(int, ...) = &D::sum;
  std::printf("%d %d %d\n", d(1, 1), p == d, p == &S::sum);
  int (*fs[2])(int, ...) = { S::sum, &N::T::add };
  std::printf("%d %d %.2f\n", fs[0](0), fs[1](2, 10, 20), M::pick(2, 1.5, 2.5));
  int (*p1)(int) = T2::s; int (*p2)(int, ...) = T2::s; int (*p3)(int, ...) = &T2::s;
  std::printf("%d %d %d\n", p1(1), p2(1, 2), p3(2));
  return 0;
}
