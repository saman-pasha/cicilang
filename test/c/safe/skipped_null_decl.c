/* skipped_null_decl.c (1.6.20): the goto jumps over the declaration of q, given null and then new memory -- q is
   garbage on the goto's path, and its free after the label is refused, as before 1.6.20 */
#include <stdlib.h>
int main(int argc, char **argv) {
    (void)argv;
    if (argc > 5) goto out;
    char *q = NULL;
    q = malloc(4);
out:
    free(q);
    return 0;
}
