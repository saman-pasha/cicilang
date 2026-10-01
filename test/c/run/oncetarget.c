/* a compound assignment and an increment evaluate their operand once (C 6.5.16.2/3, 6.5.2.4): through a call */
#include <stdio.h>
#include <stdatomic.h>
static int calls = 0, cell = 10;
static _Atomic int at = 3;
int *slot(void) { calls++; return &cell; }
_Atomic int *aslot(void) { calls++; return &at; }
int main(void) {
  *slot() += 5; *slot() *= 2; ++*slot(); (*slot())++;
  *aslot() += 4; (*aslot())++;
  printf("%d %d %d\n", cell, (int) at, calls);
  return 0;
}
