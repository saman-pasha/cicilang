// A UNION'S DEFAULT MEMBER INITIALIZER (1.6.55; [class.default.ctor]/2, [dcl.init.aggr]/5, /18): a union at namespace scope with one is
// a union class, whose default constructor gives that member its value (it was `not lowered yet: class('U')'); an anonymous union's
// member takes it in its holder's constructor and in its holder's braces (it was the storage's bytes); and a union's braced list
// gives one member, the first or the one that a default member initializer names for `{}' (each member took its item or default)
#include <cstdio>
union U { int a; float f = 2.5f; };
union A { int a = 5; float f; };
struct S { union { int a = 9; float f; }; int b = 4; };
struct S2 { union { int a = 9; float f; }; };
struct S3 { union { int a = 9; float f; }; S3() : f(1.5f) {} };
struct T { int k; union { int a = 9; float f; }; int m = 3; };
struct Q { U u; int n; };
struct P { U u; P() {} };
struct H { U u; int k = 7; };
int main() {
  U x; U y{}; U z = {7};
  A a; a.f = 1.5f;
  S s; S2 s2; S2 s2b{}; S3 s3;
  T t{1}; T t2{1, {}, 8};
  Q q{{}, 4}; Q r{{3}, 5}; P p; Q qq{}; H h;
  static U g; U *n = new U; U *m = new U{8};
  std::printf("%g %g %d | %g %d | %d %d %d %d %g | %d %d %d %d %d %d\n", x.f, y.f, z.a, a.f, a.a == 5, s.a, s.b, s2.a, s2b.a, s3.f, t.k, t.a, t.m, t2.k, t2.a, t2.m);
  std::printf("%g %d %d %d %g %g %g %d | %g %g %d\n", q.u.f, q.n, r.u.a, r.n, p.u.f, qq.u.f, h.u.f, h.k, g.f, n->f, m->a);
  delete n; delete m;
  return 0;
}
