// a lambda inside a lambda (0.117): the inner one captures the OUTER closure's captures, by value, by reference and by default,
// and -- inside a lambda that captured `this' -- the OBJECT: `[this, k] { return s + k; }' made in `[this](int k) { ... }' reads
// the class's member `s'. Also a generic lambda in a lambda, a `[*this]' copy holding an inner `[this]', and a member function called
// from the inner lambda.
#include <cstdio>
class Lam {
  int s = 8;
  int bump() { return ++s; }
public:
  int run() { auto f = [this](int k) { return [this, k]() { return s + k; }(); }; return f(2); }
  int run2() { return [this]() { return [&]() { int t = bump(); return s * 2 + t; }(); }(); }
  int run3() { return [=]() { return [=]() { return s + 1; }(); }(); }
  int run4() { int a = 5; return [this, a]() { return [=]() { return s + a; }(); }(); }
  int run5() { return [*this]() mutable { return [this]() { return ++s; }(); }(); }
  int gen() { return [this](auto x) { return [this, x]() { return s + x; }(); }(3); }
  int get() const { return s; }
};
int main() {
  int a = 1, b = 10;
  auto f1 = [a]() { return [a]() { return a + 1; }(); };
  auto f2 = [a]() { return [=]() { return a + 2; }(); };
  auto f3 = [a]() { return [&]() { return a + 3; }(); };
  auto f4 = [&a]() { return [&a]() { return a + 4; }(); };
  auto f5 = [a, b]() { return [=]() { return a + b; }(); };
  auto f6 = [=]() { return [=]() { return a * b; }(); };
  auto f7 = [&]() { return [&]() { return a - b; }(); };
  auto f8 = [a](int k) { return [a, k](int j) { return a + k + j; }(5); };
  std::printf("%d %d %d %d %d %d %d %d\n", f1(), f2(), f3(), f4(), f5(), f6(), f7(), f8(2));
  Lam l;
  std::printf("%d %d %d %d %d %d %d\n", l.run(), l.run2(), l.run3(), l.run4(), l.run5(), l.gen(), l.get());
  return 0;
}
