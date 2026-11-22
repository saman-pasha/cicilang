/* noreturn_dobreak.c (1.6.17): a break before the exit of a do-while's body leaves the loop, and a break leaves a
   do-while whose condition never ends it: each function returns, and new memory still live at main's return is refused */
#include <stdlib.h>
static void db(int c) { do { if (c) break; exit(1); } while (0); }
static void db2(int c) { do { if (c) break; } while (1); }
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    db(1);
    db2(1);
    return 0;
}
