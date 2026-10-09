/* a conditional with the literal zero for one arm and a pointer for the other (0.117; C 6.5.15/6): the zero is a null pointer constant and the
   result is a POINTER. The lowering typed it by its first arm, an int, so `c ? 0 : p' sent the pointer through `ptrtoint ... to i32' and back and a heap
   address lost its high half -- libc++'s `deque::end()' crashed at the first push_back. Both orders, over a malloc'd pointer */
#include <stdio.h>
#include <stdlib.h>
int g1(int c, int *p) { int *q = c ? 0 : p; return q ? *q : -1; }
int g2(int c, int *p) { int *q = c ? p : 0; return q ? *q : -1; }
int main(void) {
  int *h = (int *)malloc(sizeof(int));
  *h = 42;
  printf("%d %d %d %d\n", g1(0, h), g1(1, h), g2(1, h), g2(0, h));
  free(h);
  return 0;
}
