// elemborrow.c THE C++ WAY (0.272): what the safety rules of 0.265 let C keep, built by cicilang++ -- the plain functions
// noexcept, since a call that may throw past a plain struct's live owner is C++'s own refusal (the defer rule, 0.237); it
// prints what test/c/run/elemborrow.c prints
#include <stdio.h>
#include <stdlib.h>
#include "../../c/run/tvector.pl"
typedef struct { size_t len; own int *data; } buf;
void grow(buf *b) noexcept { b->data = (own int *) realloc(b->data, 2 * b->len * sizeof(int)); b->len *= 2; }
int peek(const buf *b, size_t i) noexcept { return b->data[i]; }
void set_at(buf *b, size_t i, int x) noexcept { b->data[i] = x; }
int *second(int *p) noexcept { return &p[1]; }
int *third(int *p) noexcept { return p + 2; }
int main(void) {
    vector<int> v = [int; 5, 3, 9];
    int *p = &v.data[2];
    int x = at(v, 0);
    printf("%d %d %zu\n", *p, x, len(v));
    push(v, 1);
    p = &v.data[3];
    printf("%d %zu\n", *p, len(v));
    buf b = { 2, (own int *) malloc(2 * sizeof(int)) };
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
