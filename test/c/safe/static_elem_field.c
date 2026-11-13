/* an own element of a static array stored into an own field with no move (0.307): a double free */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
typedef struct holder { own thing *p; } holder;
int main(void) {
    slot[0] = make(1);
    own holder *h = calloc(1, sizeof *h);
    if (!h) return 1;
    h->p = slot[0];
    slot[0] = make(2);
    free(h->p);
    free(h);
    free(slot[0]);
    return 0;
}
