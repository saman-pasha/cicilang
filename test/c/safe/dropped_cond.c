/* NEW MEMORY THROWN AWAY (0.309): new memory as an arm of a conditional that a statement throws away leaks its
   block, refused, dropped_memory */
#include <stdlib.h>
int main(int argc, char **argv) {
    (void)argv;
    argc > 1 ? malloc(4) : calloc(1, 4);
    return 0;
}
