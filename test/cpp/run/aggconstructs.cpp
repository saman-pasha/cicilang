// AN AGGREGATE WHOSE MEMBER CONSTRUCTS, AND AN AGGREGATE'S DEFAULT MEMBER INITIALIZERS (1.6.56; [dcl.init.aggr]/4, /5,
// [class.mem.general]/12): a member of a class with constructors and no default one took a local's or a global's braces as C's -- the
// item stored into its bytes, no constructor run, a SILENT WRONG ANSWER --; a default member initializer that names a member, calls a
// function or a member function, or makes a class's prvalue reached the lowering raw; and a temporary's took zero
#include <cstdio>
struct Y { int v; Y(int j) : v(j * 10) {} };
struct Z { int a; Y y; };
struct T { T(int j) { std::printf("T %d\n", j); } };
struct W { int a; T t; };
Z g = {7, 8};
int f() { return 7; }
struct D { int a; int b = f(); int c = a + 1; Y y = Y(5); };
struct M { int a; int g() const { return a * 3; } int b = g(); int d = this->a + 2; };
struct E { int a; int d = 9; };
int byval(E e) { return e.a + e.d; }
int main() {
  Z z = {1, 2};
  Z w{3, 4};
  Z u = {1, Y(2)};
  Z *p = new Z{5, 6};
  std::printf("%d %d %d %d %d %d %d %d\n", z.a, z.y.v, w.a, w.y.v, u.y.v, p->y.v, g.y.v, Z{1, 9}.y.v);
  delete p;
  W x = {1, 2};
  D d{4};
  std::printf("%d | %d %d %d %d\n", x.a, d.a, d.b, d.c, d.y.v);
  M m{4};
  M *q = new M{5};
  E t = E{1};
  std::printf("%d %d %d %d | %d %d %d %d\n", m.a, m.b, m.d, q->b, E{2}.d, t.d, byval(E{3}), byval({4}));
  delete q;
  return M{6}.d;
}
