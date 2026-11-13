/* a borrow of an own array of static storage returned with no tie on the result (0.307): the caller took it for new
   memory, plain pointer not consumed at its end; tie slot after the parameters makes it a borrow of the array */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
static thing *peek(void) { return slot[0]; }
int main(void) {
    slot[0] = make(3);
    thing *b = peek();
    if (b) printf("%d\n", b->v);
    free(slot[0]);
    return 0;
}
