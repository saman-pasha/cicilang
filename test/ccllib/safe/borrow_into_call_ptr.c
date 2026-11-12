/* <vector.pl>: a borrow of the buffer through a pointer to the vector, handed to a call that grows the vector (0.303;
   the forms beside the Ambitious session's finding 36): data(*pv) over pv = &v borrows v's buffer, as data(v) does,
   and grow's push_backs may replace that buffer before grow reads through the borrow -- &*pv hands what pv hands */
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
    printf("%d\n", grow(pv, data(*pv)));
    return 0;
}
