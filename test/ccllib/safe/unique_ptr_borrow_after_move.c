/* <memory.pl>: the place that get gives is a borrow of the unique_ptr: a move gives the block away (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    point pt = {1, 2};
    unique_ptr<point> p = make_unique<point>(pt);
    point *b = get(p);
    unique_ptr<point> w = p;
    return b->x + w->y;
}
