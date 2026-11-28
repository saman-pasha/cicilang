/* THE FRAME'S MEMORY FREED (1.6.54): no owner frees alloca's block, a borrow of the frame -- glibc's free met a pointer
   that no allocation gave */
#include <alloca.h>
#include <stdlib.h>
int main(void) { char *p = (char *) alloca(4); free(p); return 0; }
