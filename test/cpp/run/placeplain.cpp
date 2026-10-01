// placement new of a plain struct, a union and a scalar: value-initialized with no arguments, braced, or from a value
#include <new>
#include <cstdio>
struct S { int a; double b; char c[3]; };
union U { int i; double d; };
int main() {
  alignas(S) unsigned char buf[sizeof(S)];
  for (unsigned i = 0; i < sizeof buf; i++) buf[i] = 0xff;
  S *p = new (buf) S();
  std::printf("%d %g %d\n", p->a, p->b, p->c[2]);
  S *q = new (buf) S{3, 4.5, {1, 2, 3}};
  std::printf("%d %g %d\n", q->a, q->b, q->c[2]);
  S s0{9, 1.5, {7, 8, 9}};
  S *r = new (buf) S(s0);
  std::printf("%d %g %d\n", r->a, r->b, r->c[1]);
  for (unsigned i = 0; i < sizeof buf; i++) buf[i] = 0xff;
  U *u = new (buf) U();
  std::printf("%d\n", u->i);
  int *ip = new (buf) int(7); std::printf("%d\n", *ip);
  int *iz = new (buf) int(); std::printf("%d\n", *iz);
  return 0;
}
