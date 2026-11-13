/* NEW MEMORY THROWN AWAY (0.309): new memory in a for's first clause leaks its block, refused, dropped_memory */
#include <stdlib.h>
int main(void) {
    int i;
    for (malloc(4), i = 0; i < 2; i++) {
    }
    return 0;
}
