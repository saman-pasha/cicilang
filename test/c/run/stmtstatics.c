/* stmtstatics.c -- GNU's statement expressions whose value is a place of a static local of their own block (1.6.36),
   built as C and as C++: an element's address, a scalar's address and an array, each static storage */
#include <stdio.h>
int main(void) {
    char *s = ({ static char x[4] = "ab"; &x[0]; });
    int *q = ({ static int v = 3; &v; });
    char *t = ({ static char y[3] = "cd"; y; });
    printf("%s %d %s\n", s, *q, t);
    return 0;
}
