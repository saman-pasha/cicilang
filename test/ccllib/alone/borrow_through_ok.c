/* <vector.pl>: WHAT THE RULES OF 0.303 KEEP (0.303): a borrow through a pointer to another vector, a callee whose
   vector is const, a borrow made again after the call through the pointer and through a parameter, and another
   holder's vector -- each a borrow that no call of the program may end */
#include <stdio.h>
#include <vector.pl>
typedef struct item { int a, b; } item;
static int grow(vector<item> *v, const item *p) {
    for (int i = 0; i < 1000; i++) { item x = { i, i }; push_back(v, x); }
    return p->a;
}
static int growc(const vector<item> *v, const item *p) { return (int)size(*v) + p->a; }
typedef struct holder { vector<item> v; } holder;
static int grow2(holder *h, const item *p) {
    for (int i = 0; i < 1000; i++) { item x = { i, i }; push_back(h->v, x); }
    return p->a;
}
static int again(vector<item> *pv) { item g = { 5, 5 }; int r = grow(pv, &g); const item *p = data(*pv); return r + p->a; }
int main(void) {
    vector<item> v, w;
    item f = { 7, 7 };
    push_back(v, f);
    push_back(w, f);
    vector<item> *pv = &v;
    vector<item> *pw = &w;
    printf("%d\n", grow(pv, data(*pw)));
    printf("%d\n", growc(pw, data(*pw)));
    item g = { 3, 3 };
    int r = grow(pv, &g);
    printf("%d %d\n", r, data(*pv)->a);
    printf("%d\n", again(pw));
    holder h = {0}, j = {0};
    defer(h) { vector_item_drop(&h.v); }
    defer(j) { vector_item_drop(&j.v); }
    push_back(h.v, f);
    push_back(j.v, f);
    holder *hp = &h;
    holder *jp = &j;
    printf("%d\n", grow2(hp, data(jp->v)));
    return 0;
}
