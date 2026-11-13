/* an own element of a static array given to an owner with no move (0.307; the Ambitious session's finding 38): the
   store that replaced it freed what the owner held, a double free; move(slot[0]) empties the slot */
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
    own thing *out = slot[0];
    slot[0] = make(2);
    if (out) printf("%d\n", out->v);
    free(out);
    free(slot[0]);
    return 0;
}
