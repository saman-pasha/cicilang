/* a borrow of an own element of a static array used after a store into the element (0.307): the store freed what it
   points to */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
int main(void) {
    slot[0] = make(1);
    thing *b = slot[0];
    slot[0] = make(2);
    if (b) printf("%d\n", b->v);
    free(slot[0]);
    return 0;
}
