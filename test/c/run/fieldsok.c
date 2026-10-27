/* What the safe part lets C keep in a struct's member or an array (0.217): a local's address in a local struct, an
   array, a list of local nodes, through a local pointer to the struct, a member given another local after the first
   ended, static storage anywhere, a struct holding a local's address handed by value to a function */
#include <stdio.h>
struct S { int *p; };
struct node { int v; struct node *next; };
static int k = 5;
int *g;
struct S stat(void) { struct S s = { &k }; return s; }
int deref(struct S s) { return *s.p; }
int main(void) {
  int x = 1, y = 2;
  struct S s;
  s.p = &x;
  int *q = s.p;
  struct S *ps = &s;
  ps->p = &y;
  struct node a, b;
  a.v = 3; b.v = 4; a.next = &b; b.next = 0;
  int *arr[2];
  arr[0] = &x; arr[1] = &y;
  struct S t;
  { int z = 6; t.p = &z; printf("%d ", *t.p); }
  t.p = &x;
  g = &k;
  printf("%d %d %d %d %d %d %d %d %d\n", *q, *s.p, a.next->v, *arr[0], *arr[1], *t.p, *stat().p, deref(s), *g);
  return 0;
}
