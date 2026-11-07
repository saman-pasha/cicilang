// a member initialized from an lvalue of a class whose copy assignment is implicitly deleted (a const member): a copy, no assignment
#include <cstdio>
struct M { const int c; M(int x) : c(x) {} };
struct S { M m; int k; S(const M &x) : m(x), k(2) {} };
struct R { int &r; };
struct T { R a; T(R x) : a(x) {} int get() const { return a.r; } };
int main() { M a(3); S s(a); int v = 7; T t(R{v}); std::printf("%d %d %d\n", s.m.c, s.k, t.get()); return 0; }
