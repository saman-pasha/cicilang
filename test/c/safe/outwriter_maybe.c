/* A POINTER FREED ON ONE PATH, ITS ADDRESS HANDED TO POSIX_MEMALIGN (1.6.35): on the other path it holds new memory,
   which the call's block replaces at the call -- it was refused at the free, a use after free */
#define _POSIX_C_SOURCE 200809L
#include <stdlib.h>
int main(int argc, char **argv) { (void) argv; void *p = malloc(4); if (!p) return 1; if (argc > 5) free(p); if (posix_memalign(&p, 16, 64) != 0) return 1; free(p); return 0; }
