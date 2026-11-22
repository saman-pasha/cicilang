/* refilled.c (1.6.18): pointers that a free or a null test left holding nothing that the check follows, given new
   memory by getline through their address and copied into an own pointer that frees it, each right -- the address
   anchors such a pointer, as it anchors a local with no state; each prints as clang's build with `own' defined empty */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
static char *maybe(int n) {
    if (n <= 0) return NULL;
    return malloc((size_t)n);
}
static long refill_freed(const char *path) {
    char *line = malloc(4);
    free(line);
    line = NULL;
    size_t n = 0;
    FILE *f = fopen(path, "r");
    if (!f) return -2;
    long k = getline(&line, &n, f);
    fclose(f);
    own char *c = line;
    long r = c != NULL ? k : -3;
    free(c);
    return r;
}
static long refill_null(const char *path, int m) {
    char *line = maybe(m);
    if (!line) {
        size_t n = 0;
        FILE *f = fopen(path, "r");
        if (!f) return -2;
        long k = getline(&line, &n, f);
        fclose(f);
        own char *c = line;
        long r = c != NULL ? k : -3;
        free(c);
        return r;
    }
    free(line);
    return 7;
}
int main(void) {
    printf("%ld %ld %ld\n", refill_freed("/dev/null"), refill_null("/dev/null", 0), refill_null("/dev/null", 4));
    return 0;
}
