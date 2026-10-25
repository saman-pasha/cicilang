/* An _Atomic floating object's increments and compound assignments are one atomicrmw fadd or fsub each, as clang's
   (C17 6.5.2.4, 6.5.16.2/3; 0.206): they were a load and a store, two atomic accesses and no atomic step. */
#include <stdio.h>
_Atomic float gf = 0.5f;
_Atomic double gd = 10.0;
int main(void) {
  _Atomic float f = 1.5f;
  float a = f++;
  float b = ++f;
  float c = f--;
  float d = --f;
  f += 2.25f;
  f -= 0.5f;
  _Atomic double x = 3.0;
  double e = x++;
  x -= 1.25;
  gf += 1;
  ++gd;
  gd--;
  _Atomic _Float16 h = 1;
  h++;
  printf("%.2f %.2f %.2f %.2f %.2f\n", a, b, c, d, (double) f);
  printf("%.2f %.2f %.2f %.2f %.2f\n", e, (double) x, (double) gf, (double) gd, (double) h);
  return 0;
}
