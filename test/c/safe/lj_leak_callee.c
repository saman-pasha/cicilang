/* lj_leak_callee.c (1.6.17): a function that jumps out of its frame with new memory live: refused in the function */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf env;
static void fail(int c) {
    char *t = malloc(4);
    if (!t) exit(1);
    t[0] = (char)c;
    longjmp(env, c);
}
int main(void) { if (setjmp(env)) return 0; fail(2); return 1; }
