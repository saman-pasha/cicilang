/* NEW MEMORY THROWN AWAY (0.309): the result of a function whose result is an own pointer, thrown away leaks its
   block, refused, dropped_memory */
#include <stdlib.h>
static own int *mk(void) {
    own int *p = malloc(sizeof *p);
    if (!p) abort();
    *p = 1;
    return p;
}
int main(void) {
    mk();
    return 0;
}
