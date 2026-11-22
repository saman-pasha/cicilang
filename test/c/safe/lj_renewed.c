/* lj_renewed.c (1.6.17): an owner freed and given new memory between a setjmp and a longjmp to it -- the jump finds the
   state that the setjmp saw, but the pointer's value after the jump is not known (C17 7.13.2.1/3): the first memory, which
   is freed, or the second. Refused at the jump */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf env;
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    if (setjmp(env) == 0) {
        free(p);
        p = malloc(4);
        if (!p) return 1;
        longjmp(env, 1);
    }
    free(p);
    return 0;
}
