/* <vector.pl>: a borrow of the buffer read after a push_back through a pointer to the vector (0.303; the rule of 0.265
   through a pointer): push_back(*pv, x) may replace v's buffer, so p, data(*pv), dangles after it */
#include <stdio.h>
#include <vector.pl>
typedef struct item { int a, b; } item;
static int grow(vector<item> *v, const item *p) {
    for (int i = 0; i < 1000; i++) { item x = { i, i }; push_back(v, x); }
    return p->a;
}
int main(void) {
    vector<item> v;
    item f = { 7, 7 };
    push_back(v, f);
    vector<item> *pv = &v;
    const item *p = data(*pv);
    item x = { 1, 1 };
    for (int i = 0; i < 1000; i++) push_back(*pv, x);
    printf("%d\n", p->a);
    return 0;
}
