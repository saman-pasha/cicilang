/* lj_leak_deep.c (1.6.17): a jump two calls deep: mid() calls fail(), which jumps, so a call of mid() jumps too, and new
   memory taken after the setjmp and live at that call is refused */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf env;
static void fail(void) { longjmp(env, 1); }
static void mid(void) { fail(); }
int main(void) {
    if (setjmp(env)) return 1;
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    mid();
    free(p);
    return 0;
}
