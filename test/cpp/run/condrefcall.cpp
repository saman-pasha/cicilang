// a conditional over calls that return references is an lvalue: no temporary copy ([expr.cond]/4)
#include <cstdio>
struct P { int a; int b; };
P g1{1, 2}, g2{3, 4};
P &first() { return g1; }
P &second() { return g2; }
const P &pick(bool c) { return c ? first() : second(); }
int main() {
  P &r = true ? first() : second();
  r.a = 10;
  const P &q = pick(false);
  (false ? first() : second()).b = 40;
  std::printf("%d %d %d %d\n", g1.a, q.a, g2.b, (true ? first() : second()).a);
  return 0;
}
