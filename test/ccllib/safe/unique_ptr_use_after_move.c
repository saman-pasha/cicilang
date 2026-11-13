/* <memory.pl>: a unique_ptr that a move gave away is not used again (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    point pt = {1, 2};
    unique_ptr<point> p = make_unique<point>(pt);
    unique_ptr<point> w = p;
    return get(p)->x + w->x;
}
