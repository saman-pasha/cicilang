/* loop_pass_goto.c (1.6.19): a loop whose third pass jumps over the free of q, which the earlier passes gave new
   memory -- the label's join holds q's memory, and the assignment after the label leaves it: refused in the second
   walk of the body, where the first saw a null */
#include <stdlib.h>
int main(void) {
    char *q = NULL;
    for (int i = 0; i < 3; i++) {
        if (i == 2) goto skip;
        free(q);
    skip:
        q = malloc(4);
    }
    free(q);
    return 0;
}
