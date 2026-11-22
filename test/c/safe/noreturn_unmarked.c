/* noreturn_unmarked.c (1.6.15): a call ends its path only where the function is declared not to return. die() calls
   exit() and returns never, but nothing declares it so -- no _Noreturn, no [[noreturn]], no GCC noreturn -- and the
   safe part reads no function's body for it, as clang's analysis does not: the path goes on after the call, and new
   memory still live at main's return is refused */
#include <stdlib.h>
static void die(int c) { exit(c); }
int main(void) {
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    die(9);
    return 0;
}
