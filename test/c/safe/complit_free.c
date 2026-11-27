/* A COMPOUND LITERAL OF A BLOCK FREED (1.6.31): an object of its block, a borrow that free does not consume -- it was
   built, and the run aborted in free */
#include <stdlib.h>
int main(void) { free(&(int){ 7 }); return 0; }
