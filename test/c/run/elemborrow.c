/* TWO SAFETY RULES (0.265; CCLLIB.md's phase 0.8): what they let C keep. An element's address is a borrow of the buffer;
   a call that takes the struct by a const pointer keeps the borrows of its own fields, and one that may replace them ends
   them, after its arguments are read; a borrow taken again after such a call is good; &p[1] of a parameter is p + 1 */
#include <stdio.h>
#include <stdlib.h>
#include "tvector.pl"
typedef struct { size_t len; own int *data; } buf;
void grow(buf *b) { b->data = realloc(b->data, 2 * b->len * sizeof(int)); b->len *= 2; }
int peek(const buf *b, size_t i) { return b->data[i]; }
void set_at(buf *b, size_t i, int x) { b->data[i] = x; }
int *second(int *p) { return &p[1]; }
int *third(int *p) { return p + 2; }
int main(void) {
    vector<int> v = [int; 5, 3, 9];
    int *p = &v.data[2];
    int x = at(v, 0);
    printf("%d %d %zu\n", *p, x, len(v));
    push(v, 1);
    p = &v.data[3];
    printf("%d %zu\n", *p, len(v));
    buf b = { 2, malloc(2 * sizeof(int)) };
    b.data[0] = 7; b.data[1] = 8;
    int *q = b.data;
    printf("%d\n", peek(&b, 1) + *q);
    set_at(&b, 0, *q + 1);
    grow(&b);
    q = &b.data[0];
    printf("%d %zu\n", *q, b.len);
    int a[4] = { 1, 2, 3, 4 };
    int *r = a;
    int *s = &r[3];
    printf("%d %d %d\n", *second(a), *third(a), *s);
    free(b.data);
    return 0;
}
