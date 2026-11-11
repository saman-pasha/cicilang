/* A STORE OF A CONDITIONAL WITH NEW MEMORY ON ONE SIDE HAS NO OWNER BEHIND IT (0.290): an element of a table goes into
   a field, and the block that malloc gives on the other path does not */
#include <stdlib.h>
struct tok { char *text; int n; };
static char *names[2];
int main(int argc, char **argv) {
    (void)argv;
    struct tok t = { 0, 0 };
    t.text = argc > 1 ? names[0] : (char *)malloc(4);
    return t.text == 0;
}
