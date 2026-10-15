// A braced list assigned to a class ([expr.ass]/9) is a temporary of the class through its constructors, then the
// assignment -- unless the class's own operator= takes the list; an unevaluated operand (decltype, a requirement) makes
// no temporary, so no destructor runs for one.
#include <cstdio>
#include <initializer_list>
struct P {
  int x, y;
  P(int a, int b) : x(a), y(b) {}
  P() : x(-1), y(-1) {}
};
struct L {
  int n = 0;
  L &operator=(std::initializer_list<int> il) { n = (int) il.size(); return *this; }
};
struct Loud {
  int v;
  Loud(int x) : v(x) { std::printf("make %d\n", x); }
  ~Loud() { std::printf("drop %d\n", v); }
};
template <class T> concept Makes = requires { T(3); };
int main() {
  P p(1, 2);
  p = {7, 8};
  std::printf("%d %d\n", p.x, p.y);
  p = {};
  std::printf("%d %d\n", p.x, p.y);
  L l;
  l = {4, 5, 6};
  std::printf("%d\n", l.n);
  using T = decltype(Loud(1));
  T t(2);
  std::printf("%d %d\n", t.v, (int) Makes<Loud>);
  return 0;
}
