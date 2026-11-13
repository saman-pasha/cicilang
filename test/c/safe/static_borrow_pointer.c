/* a borrow of an own element of a static array used after a call through a pointer (0.307): such a call may store
   into every own array of static storage */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
static void nothing(void) { }
int main(void) {
    void (*fp)(void) = nothing;
    slot[0] = make(3);
    thing *b = slot[0];
    fp();
    if (b) printf("%d\n", b->v);
    free(slot[0]);
    return 0;
}
