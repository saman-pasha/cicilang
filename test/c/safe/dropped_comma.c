/* NEW MEMORY THROWN AWAY (0.309): new memory as a comma's left operand, in an initializer leaks its block, refused,
   dropped_memory */
#include <stdlib.h>
int main(void) {
    int n = (malloc(4), 3);
    return n;
}
