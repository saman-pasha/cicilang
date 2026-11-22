/* move_loop_do.c (1.6.19): a do-while's body that frees an own pointer of the loop's start and gives it nothing again --
   the next pass would free it twice: refused by the loop rule in the first pass */
#include <stdlib.h>
int main(int argc, char **argv) {
    (void)argv;
    own char *p = malloc(8);
    int k = 0;
    do { free(p); k++; } while (k < argc);
    return 0;
}
