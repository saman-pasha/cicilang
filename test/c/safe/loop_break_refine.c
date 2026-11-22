/* loop_break_refine.c (1.6.18): a while's condition refines the path that leaves where it fails, never a break's -- the
   break leaves the loop with the new memory that p holds, and nothing frees it: refused at the return */
#include <stdlib.h>
int main(int argc, char **argv) {
    (void)argv;
    char *p = malloc(4);
    while (p) {
        if (argc > 5) break;
        free(p);
        p = NULL;
    }
    return 0;
}
