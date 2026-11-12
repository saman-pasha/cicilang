/* <vector.pl>: the same through a pointer to a struct that holds the vector (0.303): hp->v over hp = &h is h.v, so
   data(hp->v) borrows h.v.data, which grow2 may replace through hp */
#include <stdio.h>
#include <vector.pl>
typedef struct item { int a, b; } item;
static int grow(vector<item> *v, const item *p) {
    for (int i = 0; i < 1000; i++) { item x = { i, i }; push_back(v, x); }
    return p->a;
}
typedef struct holder { vector<item> v; } holder;
static int grow2(holder *h, const item *p) {
    for (int i = 0; i < 1000; i++) { item x = { i, i }; push_back(h->v, x); }
    return p->a;
}
int main(void) {
    holder h = {0};
    defer(h) { vector_item_drop(&h.v); }
    item f = { 7, 7 };
    push_back(h.v, f);
    holder *hp = &h;
    printf("%d\n", grow2(hp, data(hp->v)));
    return 0;
}
