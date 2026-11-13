/* a result tied to an own array of static storage, used after a call that stores into the array (0.307) */
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
static void refill(void) { slot[0] = make(5); }
int main(void) {
    slot[0] = make(3);
    thing *b = peek();
    refill();
    if (b) printf("%d\n", b->v);
    free(slot[0]);
    return 0;
}
