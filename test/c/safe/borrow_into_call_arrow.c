/* A BORROW HANDED TO A CALL THAT MAY REPLACE ITS OWNER, THROUGH A POINTER (0.303; the forms beside the Ambitious
   session's finding 36): bp->data over bp = &b is b.data, so &bp->data[0] borrows b's buffer, which growb reallocs
   through bp before it reads through the borrow */
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
    int r = growb(bp, &bp->data[0]);
    free(b.data);
    return r - 7;
}
