/* WHAT C23 TAKES AGAIN AT FILE SCOPE (1.6.7; C23 6.7.2.3/1, 6.2.7/1): a struct, a union and an enum defined again with
   the same content -- a member's type spelled another way, a bit-field's width another constant of the same value, an
   enumerator's value written --, and a struct defined in a member and again at file scope */
#include <stdio.h>
typedef int I;
struct s { int a; long b; };
struct s { I a; long int b; };
union u { int i; float f; };
union u { int i; float f; };
enum e { A = 1, B };
enum e { A = 1, B = 2 };
struct o { struct in { signed int v; } i; };
struct in { int v; };
struct s2 { int a : 3; unsigned b : 4; };
struct s2 { int a : 1 + 2; unsigned int b : 4; };
int main(void) {
  struct s v = { 5, 6 };
  union u w = { 7 };
  struct o x = { { 8 } };
  struct s2 y = { 1, 9 };
  printf("%d %ld %d %d %d %d %d %d\n", v.a, v.b, w.i, A, B, x.i.v, y.a, y.b);
  return 0;
}
