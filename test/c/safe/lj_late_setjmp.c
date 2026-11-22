/* lj_late_setjmp.c (1.6.17): a function that may jump to a global buffer before its own setjmp of it -- its caller's
   call may jump out of the caller, which set no buffer, and the memory that the caller holds is left: refused at the call,
   as at a jump out */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf err;
static void fail(void) { longjmp(err, 1); }
static int late(int c) {
    if (c) fail();
    if (setjmp(err)) return -1;
    return 0;
}
int main(void) {
    char *buf = malloc(4);
    if (!buf) return 1;
    late(1);
    free(buf);
    return 0;
}
