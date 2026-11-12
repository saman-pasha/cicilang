/* A BORROW HANDED TO A CALL THAT MAY REPLACE ITS OWNER, held in a local (0.293): p borrows v's buffer, and grow, which
   reallocs the buffer, takes it beside &v */
#include <stdio.h>
#include <stdlib.h>
typedef struct { size_t len; own int *data; } buf;
void grow(buf *b, const int *in) {
    b->data = realloc(b->data, 2 * b->len * sizeof(int));
    b->len *= 2;
    b->data[2] = *in;
}
int main(void) {
    buf v = { 2, malloc(2 * sizeof(int)) };
    v.data[0] = 1; v.data[1] = 2;
    int *p = &v.data[1];
    grow(&v, p);
    printf("%d\n", v.data[2]);
    free(v.data);
    return 0;
}
