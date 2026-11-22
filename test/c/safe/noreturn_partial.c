/* noreturn_partial.c (1.6.17): a function that returns on one path is no function that returns never: its call goes on,
   and new memory still live at main's return is refused */
#include <stdlib.h>
static void maybe(int c) { if (c) return; exit(1); }
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    maybe(0);
    return 0;
}
