// a braced default member initializer of a PLAIN struct or union member (0.117): glibc's PTHREAD_MUTEX_INITIALIZER is `{ { 0, 0, 0, 0, 0, 0, 0,
// { 0, 0 } } }' over a union, and libc++'s std::mutex holds it as `__libcpp_mutex_t __m_ = _LIBCPP_MUTEX_INITIALIZER;' -- the list reached the
// lowering as a bare braced expression. The member is assigned a compound literal of its type
#include <cstdio>
union U { struct { int a; int b; } s; char raw[16]; };
struct P { int x; int y; };
struct M { U u = { { 1, 2 } }; P p = {3, 4}; int k = 5; M() {} };
struct N { P p = {7, 8}; U u{ { 9, 10 } }; };
int main() {
  M m; N n;
  std::printf("%d %d %d %d %d\n", m.u.s.a, m.u.s.b, m.p.x, m.p.y, m.k);
  std::printf("%d %d %d %d\n", n.p.x, n.p.y, n.u.s.a, n.u.s.b);
  return 0;
}
