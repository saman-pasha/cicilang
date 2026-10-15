// A goto into a block and over an owner's declaration, followed by the safe part (0.138): a goto into a block where an
// owner lives outside it; a goto over an owner's declaration to a label that gives it a value; a goto back into a block.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int into(int k) {
  own char *p = malloc(8);
  int r = 0;
  if (!p) return -1;
  if (k) goto in;
  r = 10;
  {
    int t = 5;
    r += t;
  in:
    r += 1;
    strcpy(p, "in");
  }
  r += (int) strlen(p);
  free(p);
  return r;
}
int over(int k) {
  int r = 0;
  if (k) goto set;
  r = 100;
  {
    own char *q = 0;
  set:
    q = malloc(4);
    if (!q) return -1;
    q[0] = 'a';
    r += q[0];
    free(q);
  }
  return r;
}
int back(int n) {
  int i = 0;
  {
  top:
    i++;
  }
  if (i < n) goto top;
  return i;
}
int main(void) {
  printf("%d %d %d %d %d\n", into(0), into(1), over(0), over(1), back(4));
  return 0;
}
