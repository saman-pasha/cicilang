// what a const member function writes (1.6.24): a mutable member, its own and a base's, through a pointer member and a
// reference member, beside a non-const member function's writes and a mutable lambda's capture; a write of any other
// member in a const member function is refused in clang++'s words (the driver gate)
#include <cstdio>
struct P { int q; };
struct B { int bm = 0; mutable int bk = 0; };
struct C : B { int m = 0; mutable int k = 0; int a[2] = {0, 0}; P s{0}; int *p; int &r; static int gv;
  C(int &x) : p(&gv), r(x) {}
  void g() const { k = 1; bk = 2; *p = 3; r = 4; ++k; k += 2; }
  void h() { m = 5; a[1] = 6; s.q = 7; bm = 8; }
};
int C::gv = 0;
int main() { int x = 0; C c(x); c.g(); c.h(); auto l = [v = 1]() mutable { v = 2; return v; }; std::printf("%d %d %d %d %d %d %d %d %d\n", c.k, c.bk, c.m, x, c.a[1], c.s.q, c.bm, l(), *c.p); return 0; }
