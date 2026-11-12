/* A BORROW READ AFTER A CALL THAT MAY REPLACE ITS OWNER, THROUGH A POINTER (0.303; the rule of 0.265): q = bp->data
   borrows b.data, and growb(bp, ...) may realloc it */
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
    int *q = bp->data;
    int r = growb(bp, &b.len);
    r = *q;
    free(b.data);
    return r - 7;
}
