/* nulldecls.c (1.6.20): pointers declared null, given new memory on the path that a goto jumps over and freed after the
   label, each right -- with no goto, out of a loop from a later pass, and in a loop's body; such a pointer is a key of
   its frame since 1.6.20, and the label's join took it for a declaration that the goto jumped over, `goto over the
   declaration of fresh memory'; each prints as clang's build with `own' defined empty, as C and as C++ */
#include <stdio.h>
#include <stdlib.h>
static int jumped(int c) {
    char *q = NULL;
    int given = 0;
    if (c) goto out;
    q = malloc(4);
    given = q != NULL;
out:
    free(q);
    return given;
}
static int left(int stop) {
    char *q = NULL;
    int n = 0;
    for (int i = 0; i < 5; i++) {
        if (i == stop) goto out;
        free(q);
        q = malloc(4);
        n++;
    }
out:
    free(q);
    return n;
}
static int inner(void) {
    int n = 0;
    for (int i = 0; i < 3; i++) {
        char *q = NULL;
        if (i == 1) goto next;
        q = malloc(4);
        n += q != NULL;
    next:
        free(q);
    }
    return n;
}
int main(void) {
    printf("%d %d %d %d %d\n", jumped(1), jumped(0), left(3), left(9), inner());
    return 0;
}
