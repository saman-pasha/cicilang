// mutable lambdas: a by-value capture is a member of the closure, writable only under `mutable' ([expr.prim.lambda.closure]/5) -- each
// copy of the closure has its own; a write through a copied pointer, to a reference capture, to a lambda's own parameter or to
// an init-capture of a mutable lambda is the program's to make. (test/cpp/lambda_const.cpp is the refusal.)
#include <cstdio>
struct P { int x; };
int main() {
  int n = 1; P p{5}; int arr[2] = {1, 2}; int *q = arr;
  auto ok1 = [n]() mutable { n++; return n; };
  auto ok2 = [p]() mutable { p.x += 2; return p.x; };
  auto ok3 = [q]() { *q = 7; q[1] = 8; return q[0]; };
  auto ok4 = [n](int k) { int m = n; m += k; return m; };
  auto ok5 = [&n]() { n++; return n; };
  auto ok6 = [=]() mutable { return ++n + p.x; };
  auto ok7 = [n]() { auto in = [](int n) { n++; return n; }; return in(n); };
  auto ok8 = [x = 5]() mutable { x *= 2; return x; };
  std::printf("%d %d %d %d %d %d %d %d\n", ok1(), ok2(), ok3(), ok4(1), ok5(), ok6(), ok7(), ok8());
  std::printf("%d %d %d\n", ok1(), ok2(), ok8());
  auto copy = ok1; std::printf("%d %d %d\n", copy(), ok1(), copy());
  return 0;
}
