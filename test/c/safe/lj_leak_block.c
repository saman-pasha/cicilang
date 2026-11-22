/* lj_leak_block.c (1.6.17): new memory live in a block that a longjmp leaves, which nothing frees: refused at the jump */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf env;
int main(void) {
    if (setjmp(env) == 0) {
        char *q = malloc(4);
        if (!q) return 1;
        q[0] = 1;
        longjmp(env, 1);
    }
    return 0;
}
