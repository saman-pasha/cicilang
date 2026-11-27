/* plain pointers that a free leaves freed and that the program gives new memory again (1.6.32): new memory after the
   free, in a line and in a loop's passes, a null after it and a free of the null, a loop that frees and empties its
   pointer, a free that a null test guards, realloc's failure, whose block stays live and is freed, and getline's new memory through a freed pointer's
   address -- each a form that the state of a freed pointer must keep */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int again(void) { char *p = malloc(4); if (!p) return -1; p[0] = 'a'; free(p); p = malloc(8); if (!p) return -1; p[0] = 'b'; int k = p[0]; free(p); return k; }
static int passes(void) { char *p = malloc(4); int n = 0; for (int i = 0; i < 3 && p; i++) { p[0] = (char) i; n += p[0]; free(p); p = malloc(4 + i); } free(p); return n; }
static int nulled(void) { char *p = malloc(4); free(p); p = NULL; free(p); return p == NULL; }
static int emptied(void) { char *p = malloc(4); int n = 0; while (p) { free(p); p = NULL; n++; } return n; }
static int maybe_freed(int k) { char *p = k ? malloc(4) : NULL; if (p) free(p); return k; }
static int grown(size_t n) { char *p = malloc(4); if (!p) return -1; char *q = realloc(p, n); if (!q) { free(p); return 0; } q[0] = 'x'; int k = q[0]; free(q); return k; }
static int refilled(void) {
    FILE *f = tmpfile();
    if (!f) return -1;
    fputs("a line\n", f);
    rewind(f);
    char *line = malloc(4);
    size_t cap = 0;
    free(line);
    line = NULL;
    ssize_t got = getline(&line, &cap, f);
    int k = got > 0 ? (int) strlen(line) : 0;
    free(line);
    fclose(f);
    return k;
}
int main(void) {
    printf("%d %d %d %d %d %d %d\n", again(), passes(), nulled(), emptied(), maybe_freed(1) + maybe_freed(0), grown(64), refilled());
    return 0;
}
