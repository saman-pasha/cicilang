/* REALLOC'S OLD BLOCK FREED WITH NO TEST OF ITS RESULT (1.6.34): it may be freed already, or not */
#include <stdlib.h>
int main(void) { char *p = malloc(4); if (!p) return 1; char *q = realloc(p, 64); free(q); free(p); return 0; }
