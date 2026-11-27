/* NEW MEMORY HANDED OUT OF A BLOCK TO A COPY THAT NEVER GIVES IT BACK (1.6.35): the copy holds it after the block, and
   its end is the leak -- it was refused at the block's end, in the inner pointer's name */
#include <stdlib.h>
int main(void) { char *p; { char *q = malloc(4); p = q; } return 0; }
