/* <vector.pl>: the same through a parameter (0.303): data(*pv) borrows the caller's buffer, pv->data, which grow may
   replace through pv */
#include <stdio.h>
#include <vector.pl>
typedef struct item { int a, b; } item;
static int grow(vector<item> *v, const item *p) {
    for (int i = 0; i < 1000; i++) { item x = { i, i }; push_back(v, x); }
    return p->a;
}
static int use(vector<item> *pv) { return grow(pv, data(*pv)); }
int main(void) {
    vector<item> v;
    item f = { 7, 7 };
    push_back(v, f);
    printf("%d\n", use(&v));
    return 0;
}
