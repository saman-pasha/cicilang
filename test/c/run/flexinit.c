/* flexible array members given their items at file scope and in a static local (1.6.25): GNU's extension, which
   clang takes -- the member an array of its items' count or of a literal's bytes, the struct's constant the literal
   struct of its constants' types, its size the struct's own; each was refused, global_init(arr(none, ...)) */
#include <stdio.h>
struct S { int n; int a[]; };
struct T { short k; char s[]; };
struct U { char c; double d[]; };
struct S s = {3, {7, 8, 9}};
static struct S t = {1, {5}};
struct S e = {0};
struct T w = {2, "abc"};
struct U u = {'x', {1.5, 2.5}};
int main(void) {
  static struct S loc = {2, {4, 6}};
  printf("%d %d %d %d %d %d %zu\n", s.n, s.a[0], s.a[2], t.n, t.a[0], e.n, sizeof(struct S));
  printf("%d %s %c %.1f %.1f %d %d\n", w.k, w.s, u.c, u.d[0], u.d[1], loc.n, loc.a[1]);
  return 0;
}
