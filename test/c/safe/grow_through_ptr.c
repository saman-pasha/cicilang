/* A CALL THAT MAY REPLACE A STRUCT'S OWN FIELDS ENDS THE BORROWS OF THEM (0.265): the struct handed by a pointer that
   borrows it, grow(pv) over pv = &v, ends them as grow(&v) does */
#include <stdio.h>
#include <stdlib.h>
typedef struct { size_t len; own int *data; } buf;
void grow(buf *b) { b->data = realloc(b->data, 2 * b->len * sizeof(int)); b->len *= 2; }
int main(void) {
    buf v = { 2, malloc(2 * sizeof(int)) };
    v.data[0] = 7; v.data[1] = 8;
    buf *pv = &v;
    int *p = v.data;
    grow(pv);
    printf("%d\n", *p);
    free(v.data);
    return 0;
}
