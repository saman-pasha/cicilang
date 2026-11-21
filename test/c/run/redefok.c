/* WHAT C TAKES AGAIN AT FILE SCOPE (1.6.7; C17 6.9.2/2, 6.7/3, 6.10.1/6): tentative definitions, a typedef of the same
   type, a prototype beside a definition, a guarded header included two times, one with a conditional past its guard,
   two headers that share a guarded block, one whose guard the file defines first, and an extern object with an
   initializer, its definition -- the walk of a second definition takes a header's items at the lines that the file's
   run keeps of it */
#include <stdio.h>
#include "redefok_g.h"
#include "redefok_g.h"
#include "redefok_c.h"
#include "redefok_c.h"
#include "redefok_sa.h"
#include "redefok_sb.h"
#define REDEFOK_T_H
#include "redefok_t.h"
static int thrice(int a) { return a + a + a; }
int y;
int y;
static int z = 3;
static int z;
extern int w;
int w = 4;
extern int e = 5;
extern const char *nm = "abc";
typedef int T;
typedef int T;
typedef T U;
typedef int U;
typedef int A[3];
typedef int A[1 + 2];
int f(void);
int f(void) { return 6; }
extern int f(void);
int main(void) {
  struct pt p = { 1, 2 };
  A a = { 7, 8, 9 };
  printf("%d %d %d %d\n", gtwice(p.y), gcounter, p.x, width());
  printf("%d %d\n", sa(1), sb(1));
  printf("%d\n", thrice(2));
  printf("%d %d %d %d %s\n", y, z, w, e, nm);
  printf("%d %d %d %d\n", (int)sizeof(T), (U)a[1], (int)sizeof(A), f());
  return 0;
}
