/* lj_head_call.c (1.6.17): a function whose setjmp of a global buffer comes after a call that may jump to it, in the same
   condition -- a setjmp that C17 7.13.1.1/4 does not allow there, which clang builds --: its caller's call may jump out of
   the caller, and the memory that the caller holds is left: refused at the call */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf err;
static void fail(void) { longjmp(err, 1); }
static int check(int c) { if (c) fail(); return c; }
static int first(int c) {
    if (check(c) || setjmp(err)) return -1;
    return 0;
}
int main(void) {
    char *buf = malloc(4);
    if (!buf) return 1;
    first(1);
    free(buf);
    return 0;
}
