/* lj_volatile.c (1.6.17): a volatile pointer given new memory after the setjmp and freed after the jump -- C keeps its
   value across the jump, but the safe part walks the second return from the state that the setjmp saw, where the pointer
   held no memory, so the memory is left by the jump: refused, volatile or not */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf env;
static void work(int c) { if (c) longjmp(env, 1); }
int main(void) {
    char *volatile buf = NULL;
    if (setjmp(env) != 0) { free(buf); return 1; }
    buf = malloc(10);
    work(1);
    free(buf);
    return 0;
}
