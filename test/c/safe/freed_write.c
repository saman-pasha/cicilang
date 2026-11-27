/* A WRITE THROUGH A FREED PLAIN POINTER (1.6.32) -- it was built, a write into memory given back */
#include <stdlib.h>
int main(void) { char *p = malloc(8); free(p); p[0] = 1; return 0; }
