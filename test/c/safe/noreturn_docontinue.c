/* noreturn_docontinue.c (1.6.17): a continue before the exit of a do-while's body goes to the condition, which ends the
   loop: the function returns, and new memory still live at main's return is refused */
#include <stdlib.h>
static void dc(int c) { do { if (c) continue; exit(1); } while (0); }
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    dc(1);
    return 0;
}
