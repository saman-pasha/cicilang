/* REALLOC'S OLD BLOCK KEPT WHERE ITS RESULT IS NULL (1.6.34; C17 7.22.3.5/4): the path that returns on a null result
   holds the old block still, and never gives it back */
#include <stdlib.h>
int main(void) { char *p = malloc(4); if (!p) return 1; char *q = realloc(p, 64); if (!q) return 1; free(q); return 0; }
