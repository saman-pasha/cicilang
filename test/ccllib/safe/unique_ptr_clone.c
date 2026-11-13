/* <memory.pl>: a unique_ptr is not copied, as C++ deletes its copy: clone has no function (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    point pt = {1, 2};
    unique_ptr<point> p = make_unique<point>(pt);
    unique_ptr<point> w = clone(p);
    return w->x;
}
