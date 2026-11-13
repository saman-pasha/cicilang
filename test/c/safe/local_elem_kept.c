/* an own element of a local array given to an owner with no move (0.307): refused before as a borrow stored, now in
   the words that name move() */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
int main(void) {
    own thing *C[2] = {0};
    C[0] = make(1);
    own thing *out = C[0];
    free(out);
    return 0;
}
