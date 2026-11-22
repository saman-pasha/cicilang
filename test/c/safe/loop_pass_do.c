/* loop_pass_do.c (1.6.19): a do-while's next pass starts from the body's end where the condition holds -- the second
   pass gives p new memory over the first pass's: refused there */
#include <stdlib.h>
int main(int argc, char **argv) {
    (void)argv;
    char *p = NULL;
    int k = 0;
    do { p = malloc(4); k++; } while (k < argc + 2);
    free(p);
    return 0;
}
