/* REALLOC'S OLD BLOCK ON ONE PATH, FREED ON THE OTHER (1.6.34): freed where the paths join, so its read is a use after
   free -- it was built, and read freed memory */
#include <stdlib.h>
int main(int argc, char **argv) { (void) argv; char *p = malloc(4); if (!p) return 1; char *q; if (argc > 5) { free(p); q = NULL; } else q = realloc(p, 64); int k = p[0]; free(q); return k; }
