/* A BORROW HANDED TO A CALL THAT MAY REPLACE ITS OWNER (0.293; the finding of a program over 0.284): &v.data[0], a
   borrow of v's buffer, beside &v, to a callee that reallocs the buffer and then writes through the borrow */
#include <stdio.h>
#include <stdlib.h>
typedef struct { size_t len; own int *data; } buf;
void grow(buf *b, int *out) { b->data = realloc(b->data, 2 * b->len * sizeof(int)); b->len *= 2; *out = 7; }
int main(void) {
    buf v = { 2, malloc(2 * sizeof(int)) };
    v.data[0] = 1; v.data[1] = 2;
    grow(&v, &v.data[0]);
    printf("%d\n", v.data[0]);
    free(v.data);
    return 0;
}
