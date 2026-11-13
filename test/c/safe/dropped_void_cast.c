/* NEW MEMORY THROWN AWAY (0.309): new memory cast to void, thrown away by name leaks its block, refused,
   dropped_memory */
#include <stdlib.h>
int main(void) {
    (void)calloc(1, 4);
    return 0;
}
