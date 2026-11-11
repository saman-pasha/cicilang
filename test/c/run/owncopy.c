/* AN ELEMENT OF AN OWN BUFFER THAT CARRIES NO POINTER IS A PLAIN VALUE'S SLOT (0.274): `own int *data' puts own with
   the pointee, so b->data[i] has the type `own int', and `b->data[i] = q[i]' over a parameter q was refused, `a borrow
   stored where it cannot be followed: 'q'' -- a number taken for a borrow. The same over a local owner and over a
   buffer of plain structs. A copy loop into an owned buffer is C's most common one */
#include <stdio.h>
#include <stdlib.h>
typedef struct pt { int x, y; } pt;
typedef struct buf { size_t n; own int *data; } buf;
typedef struct pts { size_t n; own pt *at; } pts;
static void fill(buf *b, const int *q, size_t n) {
    for (size_t i = 0; i < n; i++) b->data[i] = q[i];
    b->n = n;
}
static void place(pts *s, const pt *q, size_t n) {
    for (size_t i = 0; i < n; i++) s->at[i] = q[i];
    s->n = n;
}
static int sum(const int *q, size_t n) {
    own int *p = malloc(n * sizeof(int));
    for (size_t i = 0; i < n; i++) p[i] = q[i];
    int s = 0;
    for (size_t i = 0; i < n; i++) s += p[i];
    free(p);
    return s;
}
int main(void) {
    int a[3] = {1, 2, 3};
    pt q[2] = {{4, 5}, {6, 7}};
    buf b = {0, malloc(3 * sizeof(int))};
    pts s = {0, malloc(2 * sizeof(pt))};
    fill(&b, a, 3);
    place(&s, q, 2);
    printf("%d %d %zu %d %d %zu\n", sum(a, 3), b.data[2], b.n, s.at[0].y, s.at[1].x, s.n);
    free(b.data);
    free(s.at);
    return 0;
}
