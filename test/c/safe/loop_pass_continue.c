/* loop_pass_continue.c (1.6.19): a continue's state starts the next pass too -- the pass that gives p new memory and
   continues leaves it to the next one, whose new memory is given over it: refused in the second pass */
#include <stdlib.h>
int main(int argc, char **argv) {
    (void)argv;
    char *p = NULL;
    for (int i = 0; i < 3; i++) {
        if (i < argc) { p = malloc(4); continue; }
        free(p);
        p = NULL;
    }
    free(p);
    return 0;
}
