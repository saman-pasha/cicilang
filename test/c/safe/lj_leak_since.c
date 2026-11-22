/* lj_leak_since.c (1.6.17): new memory that a local of the setjmp's frame took after the setjmp, live where a call jumps
   back: the jump leaves it, and nothing frees it -- refused at the call */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf env;
static void fail(void) { longjmp(env, 1); }
int main(void) {
    if (setjmp(env)) return 1;
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    fail();
    free(p);
    return 0;
}
