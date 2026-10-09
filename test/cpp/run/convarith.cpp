// a built-in operator over a class with a conversion function to an arithmetic type (0.117, [over.match.oper]/3.3, [over.built]):
// the operator on what the function gives -- `m * 2' over a Meters with `operator double', `n += c' over a Counter with
// `operator int', a comparison of two such classes, unary minus and `~'; an `explicit' conversion function is not applied
#include <cstdio>
struct Meters { double v; operator double() const { return v; } };
struct Counter { int n; operator int() const { return n; } };
struct Flag { bool b; operator bool() const { return b; } };
struct Strict { int n; explicit operator int() const { return n; } };
int main() {
  Meters m{2.5};
  double d = m * 2;
  std::printf("%g %g %d\n", d, m + 0.5, (int)(m > 2.0));
  Counter c{7}, e{7};
  int n = 3;
  n += c;
  std::printf("%d %d %d %d %d\n", n, c - 2, (int)(c == e), -c, ~c);
  Flag f{true};
  int t = 0;
  t += f; t += f;
  std::printf("%d %d\n", t, (int)(f == true));
  Strict s{9};
  std::printf("%d\n", (int)s + 1);
  return 0;
}
