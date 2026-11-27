/* globalnames.c -- the program's own global objects beside names that are not theirs (1.6.36, 1.6.31's broken copies GS2
   and GS5), built as C and as C++: a local named as a global is the local's, null and freed, and a declaration that the
   program writes again with `extern', stdin's, names no object of the program's -- each was found by nothing until a
   broken copy took the test away: the local was the global's static slot, `a borrow consumed', and so was stdin */
#include <stdio.h>
#include <stdlib.h>
extern FILE *stdin;
char *buf;
static int local_named(void) { char *buf = NULL; free(buf); buf = (char *) malloc(4); if (!buf) return -1; buf[0] = 7; int k = buf[0]; free(buf); return k; }
int main(void) {
    static char x[4] = "g";
    buf = x;
    FILE *in = stdin;
    int closed = fclose(in);
    printf("%d %s %d\n", local_named(), buf, closed);
    return 0;
}
