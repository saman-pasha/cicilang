/* lj_freed_between.c (1.6.17): an owner freed between a setjmp and a longjmp to it -- the second return takes the
   state that the setjmp saw, so the free after the jump freed the memory twice; refused at the jump */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf env;
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    if (setjmp(env) == 0) {
        free(p);
        longjmp(env, 1);
    }
    free(p);
    return 0;
}
