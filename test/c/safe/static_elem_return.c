/* an own element of a static array returned as an own result with no move (0.307): the caller owned what the array
   freed at its next store; return move(slot[0]) empties the slot */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
static own thing *take(void) { return slot[0]; }
int main(void) {
    slot[0] = make(1);
    own thing *out = take();
    slot[0] = make(2);
    free(out);
    free(slot[0]);
    return 0;
}
