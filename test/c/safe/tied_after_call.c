/* A RESULT TIED TO A STRUCT WITH OWN FIELDS IS A BORROW OF THEM (0.266), with no type macro: last's result is tied to b,
   a place in b's buffer, so grow's realloc ends it */
#include <stdio.h>
#include <stdlib.h>
typedef struct { size_t len; own int *data; } buf;
int *last(buf *b) tie b { return &b->data[b->len - 1]; }
void grow(buf *b) { b->data = realloc(b->data, 2 * b->len * sizeof(int)); b->len *= 2; }
int main(void) {
    buf v = { 2, malloc(2 * sizeof(int)) };
    v.data[0] = 7; v.data[1] = 8;
    int *p = last(&v);
    grow(&v);
    printf("%d\n", *p);
    free(v.data);
    return 0;
}
