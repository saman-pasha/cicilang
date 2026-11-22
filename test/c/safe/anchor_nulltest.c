/* anchor_nulltest.c (1.6.18): a pointer that its null test found null, given a line by getline through its address in
   that branch, copied into an own pointer that is never freed -- getline's memory leaks: refused, where 1.6.17 took it */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    char *line = malloc(4);
    if (!line) {
        size_t n = 0;
        FILE *f = fopen("/dev/null", "r");
        if (!f) return 2;
        long k = getline(&line, &n, f);
        fclose(f);
        own char *c = line;
        return k < 0 && c == 0;
    }
    free(line);
    return 0;
}
