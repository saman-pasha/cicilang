/* REALLOC'S OLD BLOCK FREED WHERE ITS RESULT IS NOT NULL (1.6.34; C17 7.22.3.5/3): `if (q) free(p);' frees the block
   that realloc freed already -- it was built, and the run aborted in free */
#include <stdlib.h>
int main(void) { char *p = malloc(4); if (!p) return 1; char *q = realloc(p, 64); if (q) free(p); free(q); return 0; }
