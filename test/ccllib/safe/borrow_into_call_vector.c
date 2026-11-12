/* <vector.pl>: a borrow of an element's field handed to a call that grows the vector (0.293; the finding of a program
   over 0.284, its reduction): the callee's push_backs may replace the buffer, and its write went into the freed one */
#include <stdio.h>
#include <stdint.h>
#include <vector.pl>
typedef struct jn { uint32_t a, b; } jn;
typedef struct arena { vector<jn> nodes; } arena;
static void grow(arena *t, uint32_t *out) {
    for (int i = 0; i < 4096; i++) { jn n = { 0, 0 }; push_back(t->nodes, n); }
    *out = 7;
}
int main(void) {
    arena t = {0};
    defer(t) { vector_jn_drop(&t.nodes); }
    jn n0 = { 0, 0 };
    push_back(t.nodes, n0);
    grow(&t, &t.nodes[0].a);
    printf("%u\n", t.nodes[0].a);
    return 0;
}
