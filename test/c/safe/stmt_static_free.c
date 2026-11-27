/* A STATEMENT EXPRESSION WHOSE VALUE IS A STATIC LOCAL'S ADDRESS, FREED (1.6.36): static storage of the block, named by
   its local -- it was built, and the run aborted in free, `invalid size'; the words hold 1.6.31's name test of a compound
   literal, which its broken copy ST6 found reached by nothing */
#include <stdlib.h>
int main(void) { free(({ static int v = 3; &v; })); return 0; }
