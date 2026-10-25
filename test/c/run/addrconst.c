/* address constants at file scope and in a static local (C17 6.6/9): an array's name, an element's and a member's address,
   a member array's name, a row of a two-dimensional array, and an integer constant added or taken -- in pointers, in an array
   of pointers and in a struct's members */
#include <stdio.h>
int arr[8] = {10, 11, 12, 13, 14, 15, 16, 17};
char buf[] = "hello";
int m2[3][4] = {{0, 1, 2, 3}, {4, 5, 6, 7}, {8, 9, 10, 11}};
struct S { int a; int m[3]; } s = {1, {2, 3, 4}}, sarr[2] = {{5, {6, 7, 8}}, {9, {10, 11, 12}}};
int *p1 = arr;
int *p2 = arr + 2;
int *p3 = &arr[3];
char *p4 = buf;
int (*p5)[8] = &arr;
struct S *p6 = &sarr[1];
int *p7 = s.m;
int *p8 = &sarr[1].m[2];
const char *p9 = buf + 1;
int *p10 = 4 + arr;
int *p11 = &arr[6] - 1;
int *p12 = m2[1];
int (*p13)[4] = m2 + 2;
int *tab[] = {arr, arr + 1, &arr[7], &m2[2][3]};
struct H { const char *s; int *p; } h = {buf + 2, sarr[0].m + 1};
static int *next(void) { static int *at = arr + 5; return at++; }
int main(void) {
  printf("%d %d %d %s %d %d %d %d %s %d %d\n", *p1, *p2, *p3, p4, (*p5)[7], p6->a, *p7, *p8, p9, *p10, *p11);
  printf("%d %d | %d %d %d %d | %s %d\n", *p12, (*p13)[1], *tab[0], *tab[1], *tab[2], *tab[3], h.s, *h.p);
  int a = *next(), b = *next();
  printf("%d %d\n", a, b);
  return 0;
}
