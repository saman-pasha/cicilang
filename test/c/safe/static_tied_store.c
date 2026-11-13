/* a result tied to an own array of static storage, used after a store into the array (0.307): the tie is a borrow of
   the array in the caller, which the store ends */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
static thing *peek(void) tie slot { return slot[0]; }
int main(void) {
    slot[0] = make(3);
    thing *b = peek();
    slot[0] = make(4);
    if (b) printf("%d\n", b->v);
    free(slot[0]);
    return 0;
}
