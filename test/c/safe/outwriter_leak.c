/* A POINTER THAT HOLDS NEW MEMORY, ITS ADDRESS HANDED TO ASPRINTF (1.6.35): asprintf writes a new block through it and
   never reads it, so the old block is thrown away at the call -- it was refused at the failure path's return alone */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
int main(void) { char *p = malloc(4); if (!p) return 1; if (asprintf(&p, "%d", 5) < 0) return 1; puts(p); free(p); return 0; }
