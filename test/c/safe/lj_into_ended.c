/* lj_into_ended.c (1.6.17): a longjmp to a setjmp whose block has ended, an owner of that block live at the setjmp -- the
   second return frees it again; refused at the jump */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf env;
int main(void) {
    {
        char *p = malloc(4);
        if (!p) return 1;
        if (setjmp(env)) { free(p); return 0; }
        free(p);
    }
    longjmp(env, 1);
}
