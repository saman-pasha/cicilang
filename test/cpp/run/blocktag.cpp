#include <cstdio>
// a local struct is its block's own type ([basic.scope.block], [class.local]), defined with its declarators: two
// functions' `struct S', a block's beside the file's, a nested block's over its enclosing block's, a self-referential one,
// a union
struct S { char c; };
int f(void) { struct S { int a; } s = { 1 }; return (int) sizeof s + s.a; }
int g(void) {
  struct S { long a; char c[20]; } s;
  s.a = 5000000000L;
  int r = (int) sizeof s * 10 + (int) (s.a / 1000000000L);
  {
    struct S { short x, y; } t = { 3, 4 };
    struct S *p = &t;
    r = r * 100 + (int) sizeof t + p->y;
  }
  struct S *q = &s;
  return r * 10 + (int) (q->a % 7);
}
int h(void) {
  struct S { int v; struct S *next; } n2 = { 2, 0 }, n1 = { 1, &n2 };
  union U { int i; char b[8]; } u;
  u.i = 0x01020304;
  return n1.next->v * 1000 + (int) sizeof(union U) * 10 + u.b[0];
}
int k(void) { union U { long l; } w = { 9 }; return (int) w.l + (int) sizeof w; }
int main(void) {
  struct S top = { 'z' };
  std::printf("%d %d %d %d %d %zu\n", f(), g(), h(), k(), (int) top.c, sizeof top);
  return 0;
}
