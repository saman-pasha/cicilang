/* anchor_freed.c (1.6.18): a pointer freed and set null, given a line by getline through its address, copied into an
   own pointer that is never freed -- getline's memory leaks: refused. The address anchors a pointer that holds nothing
   that the check follows, as it anchors a local with no state; with no anchor, its copy was null */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    char *line = malloc(4);
    free(line);
    line = NULL;
    size_t n = 0;
    FILE *f = fopen("/dev/null", "r");
    if (!f) return 2;
    long k = getline(&line, &n, f);
    fclose(f);
    own char *c = line;
    return k < 0 && c == 0;
}
