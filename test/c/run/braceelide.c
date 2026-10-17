/* BRACE ELISION OF A SCALAR ITEM (0.164; C 6.7.9/20): a scalar item for an array member of scalars is the array's first
   element, however many items and members remain -- a one-element array, an array member with a member after it,
   globals and locals; a string literal for a char array is still the array's value */
#include <stdio.h>
struct W { int a[1]; };
struct S { int a[2]; int b; };
struct N { char name[8]; int v; };
struct T { short s[3]; double d; unsigned char c[2]; };
struct W gw = {7};
struct S gs = {1, 2};
struct N gn = {"glob", 3};
struct T gt = {1, 2, 3, 4.5, 6};
static const struct S cs = {8};
int main(void) {
  struct W w = {9};
  struct S s = {3, 4};
  struct N n = {"loc", 5};
  struct T t = {7, 8, 9, 1.5, 10, 11};
  printf("%d | %d %d %d | %s %d | %d %d %d %.1f %d %d\n", gw.a[0], gs.a[0], gs.a[1], gs.b, gn.name, gn.v, gt.s[0], gt.s[1], gt.s[2], gt.d, gt.c[0], gt.c[1]);
  printf("%d %d %d\n", cs.a[0], cs.a[1], cs.b);
  printf("%d | %d %d %d | %s %d | %d %d %d %.1f %d %d\n", w.a[0], s.a[0], s.a[1], s.b, n.name, n.v, t.s[0], t.s[1], t.s[2], t.d, t.c[0], t.c[1]);
  return 0;
}
