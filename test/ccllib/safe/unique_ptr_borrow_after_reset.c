/* <memory.pl>: the place that get gives is a borrow of the unique_ptr: reset may free it (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    point pt = {1, 2};
    unique_ptr<point> p = make_unique<point>(pt);
    point *b = get(p);
    reset(p);
    return b->x;
}
