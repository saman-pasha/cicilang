/* A POINTER TO A COMPOUND LITERAL FREED (1.6.31): the plain local holds a borrow of the block's object -- it was
   built, and the run aborted in free */
#include <stdlib.h>
int main(void) { int *o = &(int){ 7 }; *o += 1; free(o); return 0; }
