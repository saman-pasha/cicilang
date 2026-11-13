/* <memory.pl>: make_unique<T> takes one value of T, or none (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    point pt = {1, 2};
    unique_ptr<point> p = make_unique<point>(pt, pt);
    return p->x;
}
