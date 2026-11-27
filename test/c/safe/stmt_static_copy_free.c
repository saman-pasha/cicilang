/* A POINTER THAT A STATEMENT EXPRESSION GAVE FROM ITS STATIC LOCAL'S ARRAY, FREED (1.6.36): it was built, and the run
   aborted in free, `invalid size' */
#include <stdlib.h>
int main(void) { char *s = ({ static char x[4] = "ab"; &x[0]; }); free(s); return 0; }
