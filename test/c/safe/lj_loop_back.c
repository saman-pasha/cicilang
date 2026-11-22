/* lj_loop_back.c (1.6.19): a jump that a later pass of a loop makes to the setjmp of an earlier pass, which the walk meets
   before the setjmp -- the pointer that the earlier pass gave new memory after its setjmp is not known after the jump,
   and clang -O2's build frees the memory twice: refused at the jump of the second pass */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf e;
int main(void) {
    char *p = NULL;
    for (int i = 0; i < 3; i++) {
        if (i == 2) longjmp(e, 1);
        if (setjmp(e) != 0) { free(p); return 0; }
        free(p);
        p = malloc(4);
    }
    free(p);
    return 0;
}
