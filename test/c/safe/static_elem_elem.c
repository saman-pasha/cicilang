/* an own element of a static array stored into another element with no move (0.307): the two slots held one block,
   and the store into the first freed it under the second */
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
    slot[1] = slot[0];
    slot[0] = make(2);
    free(slot[0]);
    free(slot[1]);
    return 0;
}
