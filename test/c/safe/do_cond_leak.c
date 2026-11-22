/* do_cond_leak.c (1.6.18): a do-while's path after it leaves from the body's end where the condition fails -- p holds
   new memory there, and nothing frees it: refused at the return */
#include <stdlib.h>
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 0;
    do { p[0]++; } while (p[0] < 3);
    return 0;
}
