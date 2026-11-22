/* noreturn_goto.c (1.6.17): a function that a goto leaves past its exit returns: no function with a label is taken as one
   that returns never, and new memory still live at main's return is refused */
#include <stdlib.h>
static void skip(int c) { if (c) goto out; exit(1); out: ; }
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    skip(1);
    return 0;
}
