/* A FREED PLAIN POINTER COPIED (1.6.32; C17 6.2.4/2: its value is indeterminate) -- it was built, the copy null to
   the check */
#include <stdlib.h>
int main(void) { char *p = malloc(8); free(p); char *q = p; return q != 0; }
