/* REALLOC'S OLD BLOCK ON ONE PATH, NEW MEMORY ON THE OTHER (1.6.34): the join may be freed, and its free a double free
   where realloc gave a new block -- it was built */
#include <stdlib.h>
int main(int argc, char **argv) { (void) argv; char *p = malloc(4); if (!p) return 1; char *q = NULL; if (argc > 5) q = realloc(p, 64); free(p); free(q); return 0; }
