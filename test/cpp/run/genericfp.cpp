// a captureless GENERIC lambda converts to a function pointer: the conversion template deduces its parameters from
// the target's ([expr.prim.lambda.closure]/9)
#include <cstdio>
int apply(int (*f)(int), int x) { return f(x); }
double applyd(double (*f)(double, double), double a, double b) { return f(a, b); }
int main() {
  int (*inc)(int) = [](auto x) { return x + 1; };
  double (*add)(double, double) = [](auto a, auto b) { return a + b; };
  std::printf("%d %d %g %g\n", inc(4), apply([](auto v) { return v * 3; }, 5), add(1.5, 2.0), applyd([](auto a, auto b) { return a * b; }, 2.0, 4.0));
  return 0;
}
