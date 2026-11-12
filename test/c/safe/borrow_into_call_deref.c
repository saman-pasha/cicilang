/* ... and (*bp).data, which is bp->data (C17 6.5.2.3/4; 0.303): it had no place of its own to the check, and its
   borrow none */
#include <stdio.h>
#include <stdlib.h>
typedef struct buf { own int *data; int len; } buf;
static int growb(buf *b, const int *p) {
    b->data = realloc(b->data, 4096 * sizeof(int));
    if (!b->data) abort();
    return *p;
}
int main(void) {
    buf b = { 0, 1 };
    b.data = malloc(8);
    if (!b.data) return 1;
    b.data[0] = 7;
    buf *bp = &b;
    int r = growb(bp, (*bp).data);
    free(b.data);
    return r - 7;
}
