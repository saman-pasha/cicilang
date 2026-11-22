/* noreturn_loopbreak.c (1.6.17): a loop that a break leaves ends -- a while and a for --: each function returns, its call
   goes on, and new memory still live at main's return is refused */
#include <stdlib.h>
static void brk(int c) { while (1) { if (c) break; exit(1); } }
static void brk2(int c) { for (;;) { if (c) break; exit(1); } }
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    brk(1);
    brk2(1);
    return 0;
}
