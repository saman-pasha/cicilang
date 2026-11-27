/* handout.c -- new memory that a copy of an outer scope holds at the end of its pointer's scope, and the library
   functions that write a new block through their first argument (1.6.35), built as C and as C++. C17 6.2.4/2: an
   allocated object outlives the pointer that held it; POSIX: asprintf and vasprintf store the string that they allocate
   in *strp, posix_memalign its block in *memptr, and none of them reads it. */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* a block's pointer copied out of the block */
static int copied_out(void) {
    char *p;
    { char *q = (char *)malloc(4); if (!q) return -1; strcpy(q, "ab"); p = q; }
    int k = (int)strlen(p); free(p); return k;
}
/* realloc's idiom in a loop's body: the result's local is the loop's own */
static int grown_in_loop(void) {
    int i = 0;
    char *p = (char *)malloc(4); if (!p) return -1;
    do {
        char *q = (char *)realloc(p, 64 + i); if (!q) { free(p); return -1; }
        p = q; p[i] = 'a' + i;
    } while (++i < 3);
    int k = p[2]; free(p); return k;
}
/* each pass's block given to the loop's pointer, the last one freed */
static int passes(void) {
    char *p = NULL; int n = 0;
    for (int i = 0; i < 3; i++) { char *q = (char *)malloc(4); if (!q) break; free(p); p = q; n++; }
    free(p); return n;
}
/* a freed pointer given a new block by asprintf, in a condition and in a declaration */
static int printed(void) {
    char *p = (char *)malloc(4); if (!p) return -1;
    free(p);
    if (asprintf(&p, "%d", 42) < 0) return -1;
    int k = (int)strlen(p); free(p);
    int r = asprintf(&p, "%s-%d", "x", 7); if (r < 0) return -1;
    k = k * 10 + (int)strlen(p); free(p);
    char *s; if (asprintf(&s, "%c", 'z') < 0) return -1;
    k = k * 10 + (int)strlen(s); free(s);
    return k;
}
static int vprinted(char **out, const char *f, ...) {
    va_list ap; va_start(ap, f);
    int r = vasprintf(out, f, ap);
    va_end(ap); return r;
}
/* a block aligned by posix_memalign through a freed pointer's address */
static int aligned(void) {
    void *p = malloc(4); if (!p) return -1;
    free(p);
    if (posix_memalign(&p, 64, 128) != 0) return -1;
    int k = (int)((unsigned long)p % 64); free(p); return k;
}
int main(void) {
    char *v; int n = vprinted(&v, "%d%d", 1, 23);
    if (n < 0) return 1;
    printf("%d %d %d %d %d %s\n", copied_out(), grown_in_loop(), passes(), printed(), aligned(), v);
    free(v);
    return 0;
}
