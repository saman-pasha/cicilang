/* an element of an own array member of a static struct given to an owner with no move (0.307): a double free */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
typedef struct table { own thing *a[2]; } table;
static table g;
int main(void) {
    g.a[0] = make(1);
    own thing *out = g.a[0];
    g.a[0] = make(2);
    free(out);
    free(g.a[0]);
    return 0;
}
