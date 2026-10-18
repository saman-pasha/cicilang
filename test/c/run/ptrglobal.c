/* pointer globals from integer constants, arrays bounded by constant expressions (C 6.3.2.3/3, 6.6/9, 6.7.6.2/1; 0.179): a
   null pointer constant is null in a global's constant -- 0, 0L, 0ll, NULL, (void *) 0, (int *) 0, (long) 0 -- another integer
   the address it names, a pointer constant cast to another pointer type itself; `int *p = 0;' was `global ptr 0', which LLVM
   refused, and `int *p = NULL;' and `long b[1 + 1] = { 7, 16 };' were refused by name */
#include <stdio.h>
#include <stddef.h>
static int x = 5;
int *p0 = 0; int *p1 = 0L; int *p2 = 0ll; int *p3 = NULL; void *p4 = (void *) 0; int *p5 = (int *) 0; int *p6 = (long) 0;
int *p7 = (int *) 4096; char *s0 = (char *) "lit"; void *a0 = (void *) &x; int (*fp)(int) = 0; int (*fq)(int) = NULL;
int *arr[3] = { 0, NULL, &x };
struct node { int v; struct node *next; const char *name; } n0 = { 1, 0, NULL }, n1 = { 2, &n0, "one" };
enum { K = 3 };
long b0[1 + 1] = { 7, 16 }; long b1[(long) 2] = { 1, 2 }; long b2[K] = { 3, 4, 5 }; long long b3[2ll] = { 8ll, 9ll };
char buf[sizeof(int) * 2] = "abc"; int cnt[sizeof b2 / sizeof b2[0]];
static int twice(int k) { return 2 * k; }
int main(void) {
  static int *sp = NULL; static const char *sn = 0;
  printf("%d %d %d %d %d %d %d\n", p0 == 0, p1 == 0, p2 == 0, p3 == NULL, p4 == 0, p5 == 0, p6 == 0);
  printf("%ld %s %d %d %d\n", (long) p7, s0, *(int *) a0, fp == 0, fq == NULL);
  printf("%d %d %d\n", arr[0] == 0, arr[1] == NULL, *arr[2]);
  printf("%d %d %s %s %d\n", n0.next == 0, n1.next->v, n0.name == NULL ? "null" : n0.name, n1.name, sp == 0 && sn == 0);
  printf("%ld %ld %ld %lld %zu %s %zu %zu\n", b0[1], b1[1], b2[2], b3[1], sizeof buf, buf, sizeof cnt / sizeof cnt[0], sizeof b3);
  fp = twice; printf("%d\n", fp(21));
  return 0;
}
