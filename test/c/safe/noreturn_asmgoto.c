/* noreturn_asmgoto.c (1.6.17): an `__asm__ goto' that leaves past the exit to a label: no function with a label is taken as
   one that returns never, and new memory still live at main's return is refused */
#include <stdlib.h>
static void jumpy(int c) {
    __asm__ goto ("" : : : : out);
    exit(1);
out:
    (void)c;
}
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    jumpy(1);
    return 0;
}
