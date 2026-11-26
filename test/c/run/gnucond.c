/* GNU's conditional with no middle operand (1.6.22): `x ?: y' is `x ? x : y' with x evaluated once -- a constant, a
   name or a member read twice, any other operand held in a temporary of its type; and a statement expression of
   declarations alone, then its value, gives the check that value: a pointer from a function whose every return is
   static storage is no new memory through it, each local's initializer with the earlier ones' in their places, so that
   a local of the block never names an outer local of its name. Until 1.6.22 `x ?: y' was a syntax error */
#include <stdio.h>
#include <stdlib.h>
struct box { int n; int *p; };
static int calls;
static int next(int v) { calls++; return v; }
static const char *pick(int k) { calls++; return k ? "set" : NULL; }
int main(void) {
  int a = 0, b = 7;
  int z = a ?: 5;
  int w = b ?: 5;
  int c = next(0) ?: next(3);
  int d = next(4) ?: next(9);
  const char *n = pick(0) ?: "none";
  const char *m = pick(1) ?: "none";
  long l = (a ?: 2L) + (b ?: 3L);
  double f = a ?: 1.5;
  int k = 1 ?: 2;
  enum { E = 0 ?: 4 };
  static int arr[3 ?: 1];
  int *p = &b;
  int *q = p ?: &a;
  struct box bx = { 0, &b };
  int bn = bx.n ?: *bx.p;
  int *bp = bx.p ?: &a;
  const char *s = ({ const char *t = pick(1); t ? t : "none"; });
  char *t = malloc(4);
  const char *u = ({ const char *t = pick(1); const char *v = t; v ?: "none"; });
  free(t);
  printf("%d %d %d %d %s %s %ld %g %d %d %zu %d %d %d %s %s\n", z, w, c, d, n, m, l, f, k, E, sizeof arr / sizeof arr[0], *q, bn, *bp, s, u);
  printf("%d\n", calls);
  return 0;
}
