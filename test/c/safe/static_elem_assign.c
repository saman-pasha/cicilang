/* an own element of a static array assigned to an owner with no move (0.307): a double free, as an initializer's */
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
    own thing *out = 0;
    out = slot[0];
    slot[0] = make(2);
    free(out);
    free(slot[0]);
    return 0;
}
