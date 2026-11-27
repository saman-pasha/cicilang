/* A branch of an if whose condition folds to the other one, and that holds no label, is one that clang's code
   generation drops (1.6.39): a call of a function marked with GCC's error in it is no call that clang names, and a
   function that it alone calls needs no definition */
#include <stdio.h>
__attribute__((error("never call"))) void never(void);
void nowhere(int);
#define DEBUG 0
int main(void) {
  if (0) never();
  if (1) printf("one\n"); else never();
  if (sizeof(int) == 3) { never(); nowhere(1); }
  if (DEBUG) { int x = 2; nowhere(x); }
  for (int i = 0; i < 2; i++) { if (0) { never(); continue; } printf("pass %d\n", i); }
  printf("ok\n");
  return 0;
}
