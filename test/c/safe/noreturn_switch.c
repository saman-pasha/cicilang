/* noreturn_switch.c (1.6.17): the safe part follows no switch to find that a function returns never -- each case of sw()
   ends the program, but its call goes on, and new memory still live at main's return is refused */
#include <stdlib.h>
static void sw(int c) { switch (c) { case 0: exit(0); default: abort(); } }
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    sw(0);
    return 0;
}
