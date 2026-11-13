/* NEW MEMORY THROWN AWAY (0.309): the clone macro's copy thrown away leaks its block, refused, dropped_memory */
#include <stdlib.h>
int main(void) {
    own int *p = malloc(sizeof *p);
    if (!p) return 1;
    *p = 1;
    clone(p);
    free(p);
    return 0;
}
