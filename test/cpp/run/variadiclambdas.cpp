// Lambdas with an ellipsis (1.6.58; [expr.prim.lambda.closure]/1): the call operator takes the arguments past its named
// parameters, read by va_arg in its body -- with no capture, with a capture by value and by reference, mutable, of an
// ellipsis alone, and called again through a reference; the reader dropped the ellipsis, and each call was `not lowered
// yet: call(id(sum))'
#include <cstdio>
#include <cstdarg>
int main() {
  auto sum = [](int n, ...) { va_list ap; va_start(ap, n); int s = 0; for (int i = 0; i < n; i++) s += va_arg(ap, int); va_end(ap); return s; };
  int k = 100, total = 0;
  auto cap = [k, &total](int n, ...) { va_list ap; va_start(ap, n); int s = k; for (int i = 0; i < n; i++) s += va_arg(ap, int); va_end(ap); total += s; return s; };
  auto count = [c = 0](const char *f, ...) mutable { va_list ap; va_start(ap, f); double d = va_arg(ap, double); va_end(ap); c++; return c * 1000 + (int) d; };
  auto none = [](...) { return 7; };
  auto &ref = sum;
  std::printf("%d %d %d %d\n", sum(3, 1, 2, 3), cap(2, 5, 6), sum(0), ref(2, 10, 20));
  std::printf("%d %d %d %d\n", count("x", 2.5), count("y", 3.5), none(1, 2.0, "z"), total);
  return 0;
}
