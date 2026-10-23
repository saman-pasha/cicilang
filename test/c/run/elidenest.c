/* BRACE ELISION INTO AN ARRAY'S ELEMENTS (C 6.7.9/20; 0.194): an element that is an array or a struct, given a scalar,
   takes the items it needs, from a designator on too (`[1] = 7, 8, 9', `.q = 4, 5'), locally and in a global; a string
   is a char array's own value */
#include <stdio.h>
struct P { int x, y; };
struct Q { int a, b; };
struct R { int z; struct Q q; int c; };
int g[2][2] = {1, 2, 3, 4};
struct P gp[2] = {5, 6, 7, 8};
char gn[2][3] = {'a', 'b', 0, 'c', 'd', 0};
char gs[2][4] = {"ab", "cd"};
int g3[2][2][2] = {1, 2, 3, 4, 5, 6, 7};
int gc[2][3] = {[1] = 7, 8, 9};
struct R gd = {.q = 1, 2, 3};
int main(void) {
  int a[2][2] = {1, 2, 3, 4};
  struct P ps[2] = {1, 2, 3, 4};
  int b[3][2] = {{1}, 2, 3, 4};
  int c[2][3] = {[1] = 7, 8, 9};
  struct R d = {.q = 4, 5, 6};
  struct R e = {9, .q = 1, 2};
  printf("%d %d %d %d | %d %d %d %d\n", g[0][1], g[1][0], gp[1].x, gp[1].y, a[0][1], a[1][1], ps[1].x, ps[1].y);
  printf("%s %s %s %s | %d %d %d %d %d | %d %d %d\n", gn[0], gn[1], gs[0], gs[1], b[0][0], b[0][1], b[1][0], b[1][1], b[2][0], c[1][0], c[1][1], c[1][2]);
  printf("%d %d %d | %d %d %d %d %d %d %d\n", g3[0][1][1], g3[1][1][0], g3[1][1][1], gc[1][0], gc[1][1], gc[1][2], gc[0][0], gd.q.a, gd.q.b, gd.c);
  printf("%d %d %d %d | %d %d %d %d\n", d.q.a, d.q.b, d.c, d.z, e.z, e.q.a, e.q.b, e.c);
  return 0;
}
