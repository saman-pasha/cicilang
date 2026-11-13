/* NEW MEMORY THROWN AWAY (0.309): realloc's block thrown away, the old one freed or moved leaks its block, refused,
   dropped_memory */
#include <stdlib.h>
int main(void) {
    own char *p = malloc(4);
    if (!p) return 1;
    realloc(p, 8);
    return 0;
}
