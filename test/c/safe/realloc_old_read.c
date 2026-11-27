/* REALLOC'S OLD BLOCK READ WHERE ITS RESULT IS NOT NULL (1.6.34): the old name points into memory that realloc freed */
#include <stdlib.h>
int main(void) { char *p = malloc(4); if (!p) return 1; char *q = realloc(p, 64); if (!q) { free(p); return 1; } p[0] = 1; free(q); return 0; }
