/* loop_pass_owner.c (1.6.19): an own pointer given new memory in each pass of a while loop: the second pass writes
   over the first pass's owner, still live -- refused */
#include <stdlib.h>
int main(int argc, char **argv) {
    (void)argv;
    own char *p = NULL;
    int n = argc + 2;
    while (n-- > 0) p = malloc(4);
    free(p);
    return 0;
}
