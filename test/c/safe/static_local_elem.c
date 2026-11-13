/* an own element of a static local array given to an owner with no move (0.307): the array is zero at birth, and its
   element is its own still */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
int main(void) {
    static own thing *s[2];
    s[0] = make(1);
    own thing *out = s[0];
    s[0] = make(2);
    free(out);
    return 0;
}
