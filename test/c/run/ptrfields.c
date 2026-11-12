/* WHAT THE RULES OF 0.303 KEEP IN C (0.303): through a pointer to a struct with an own field, the address of a field
   that no call replaces, and another struct's buffer, are no borrows of what growb may replace */
#include <stdio.h>
#include <stdlib.h>
typedef struct buf { own int *data; int len; } buf;
static int growb(buf *b, const int *p) {
    b->data = realloc(b->data, 4096 * sizeof(int));
    if (!b->data) abort();
    b->data[0] = 9;
    return *p;
}
int main(void) {
    buf b = { 0, 1 }, c = { 0, 2 };
    b.data = malloc(8);
    if (!b.data) return 1;
    c.data = malloc(8);
    if (!c.data) { free(b.data); return 1; }
    c.data[0] = 7;
    buf *bp = &b;
    buf *cp = &c;
    int r1 = growb(bp, &bp->len);
    int r2 = growb(bp, &cp->data[0]);
    printf("%d %d %d %d\n", r1, r2, bp->data[0], (*bp).len);
    free(b.data);
    free(c.data);
    return 0;
}
