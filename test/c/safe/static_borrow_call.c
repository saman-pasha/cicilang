/* a borrow of an own element of a static array used after a call that stores into the array (0.307): it read what
   the callee's store freed, and was taken */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
static void refill(void) { slot[0] = make(2); }
int main(void) {
    slot[0] = make(1);
    thing *b = slot[0];
    refill();
    if (b) printf("%d\n", b->v);
    free(slot[0]);
    return 0;
}
