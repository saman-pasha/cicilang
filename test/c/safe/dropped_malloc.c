/* NEW MEMORY THROWN AWAY (0.309): malloc's block thrown away by an expression statement leaks its block, refused,
   dropped_memory */
#include <stdlib.h>
int main(void) {
    malloc(10);
    return 0;
}
