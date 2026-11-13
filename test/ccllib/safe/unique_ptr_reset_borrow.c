/* <memory.pl>: reset(p, r) takes an own pointer: a borrow of another unique_ptr is none (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    point pt = {1, 2};
    unique_ptr<point> p = make_unique<point>(pt);
    unique_ptr<point> q = make_unique<point>(pt);
    reset(p, get(q));
    return p->x;
}
