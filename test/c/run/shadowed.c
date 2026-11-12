/* SHADOWED NAMES (0.297): a name that a block declares again hides the outer one's states -- a plain int over an own
   pointer, a plain int over a parameter whose struct has an own field, a pointer of the block over a pointer parameter,
   given a value at its declaration and after it -- and the outer ones answer again after the block. Each was refused,
   `owner overwritten while live' or `use of a borrow after its owner was consumed', where clang builds it */
#include <stdio.h>
#include <stdlib.h>
typedef struct buf { own int *data; int n; } buf;
static buf gb = { 0, 1 };
static int field(buf *p) {
    int r = 0;
    { int p; p = 4; r = p; }
    return r + p->n;
}
static int self(int *p) {
    int x = 2, r = 0;
    { int *p = &x; r = *p; }
    { int *p; p = &x; r += *p; }
    return r + *p;
}
int main(void) {
    int k = field(&gb);
    int a = 5;
    int s = self(&a);
    own int *v = malloc(sizeof(int));
    if (!v) return 1;
    *v = 7;
    { int v; v = 3; printf("%d ", v); }
    printf("%d %d %d\n", *v, k, s);
    free(v);
    return 0;
}
