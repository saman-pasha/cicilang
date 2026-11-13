/* NEW MEMORY THROWN AWAY (0.309): new memory in a for's third clause, at each step leaks its block, refused,
   dropped_memory */
#include <stdlib.h>
int main(void) {
    for (int i = 0; i < 2; i++, malloc(4)) {
    }
    return 0;
}
