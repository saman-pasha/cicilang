/* loop_break_leak.c (1.6.15): a loop with a constant condition ends by its breaks, and the path after it is theirs: new
   memory that a break leaves live is refused at the function's return, as before the rule */
#include <stdlib.h>
int main(int argc, char **argv) {
    (void)argv;
    char *p = malloc(4);
    if (!p) return 1;
    while (1) {
        p[0] = (char)argc;
        if (argc++ > 3) break;
    }
    return 0;
}
