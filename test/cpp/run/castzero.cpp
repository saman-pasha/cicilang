#include <cstdio>
#include <string>
// a builtin type's functional cast written with no argument is the type's zero ([expr.type.conv]/2, [dcl.init]/8):
// as an initializer, an argument, a constructor's argument in parentheses and in braces, in a template's body
struct P {
  P(int n, char c) : n(n), c(c) {}
  int n;
  char c;
};
template <class S> int f(const wchar_t *a, const wchar_t *b) {
  S s(2 * (b - a), char());
  return (int) s.size() + (int) s[0];
}
int g(int x) { return x + 1; }
int main() {
  std::string s(3, char());
  P p(4, char());
  P q{5, char{}};
  int k = int();
  double d(double{});
  unsigned u = unsigned();
  bool b = bool{};
  std::printf("%zu %d %d %d %d %d %g %u %d %d\n", s.size(), (int) s[1], p.n, (int) p.c, q.n, k, d, u, (int) b, g(int()));
  std::printf("%d\n", f<std::string>(L"ab", L"abc" + 3));
  return 0;
}
