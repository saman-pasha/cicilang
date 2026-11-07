// what a deleted member template, a deleted function template, a deleted move and a reference or const member leave callable (0.258)
#include <cstdio>
#include <memory>
#include <utility>
struct S1 { template <class T> int f(T) = delete; int f(int) { return 4; } };
template <class T> int h(T *) = delete;
int h(int *) { return 5; }
struct M3 { int v = 3; M3() = default; M3(const M3 &) = default; M3(M3 &&) = delete; };
struct S3 { M3 m; };
struct S4 { std::unique_ptr<int> p; int k = 2; };
struct R5 { int &r; };
struct C5 { const int c; int d; };
int main() {
  S1 s; int i = 0; std::printf("%d %d\n", s.f(1), h(&i));
  S3 a; S3 b = std::move(a); std::printf("%d\n", b.m.v);
  S4 x; x.p = std::make_unique<int>(5); S4 y = std::move(x); S4 z{std::make_unique<int>(7), 3}; std::printf("%d %d %d %d\n", *y.p, y.k, *z.p, x.p ? 1 : 0);
  int q = 1; R5 r1{q}; R5 r2 = r1; C5 c1{1, 2}; C5 c2 = c1; std::printf("%d %d %d\n", r2.r, c2.c, c2.d);
}
