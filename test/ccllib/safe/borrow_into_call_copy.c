/* <vector.pl>: the same through a local pointer that copies a pointer parameter (0.303): hp->v over hp = h is h->v,
   the caller's, whose buffer grow2 may replace */
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
static int use(holder *h) { holder *hp = h; return grow2(hp, data(hp->v)); }
int main(void) {
    holder h = {0};
    defer(h) { vector_item_drop(&h.v); }
    item f = { 7, 7 };
    push_back(h.v, f);
    printf("%d\n", use(&h));
    return 0;
}
