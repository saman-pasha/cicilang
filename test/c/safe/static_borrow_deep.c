/* a borrow of an own element of a static array used after a call whose callee calls a function that stores into the
   array (0.307): a function writes the arrays of the functions that it calls */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
static void inner(void) { slot[0] = make(9); }
static void outer(void) { inner(); }
int main(void) {
    slot[0] = make(4);
    thing *b = slot[0];
    outer();
    if (b) printf("%d\n", b->v);
    free(slot[0]);
    return 0;
}
