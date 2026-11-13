/* <memory.pl>: make_unique_for_overwrite<T> takes no value (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    point pt = {1, 2};
    unique_ptr<point> p = make_unique_for_overwrite<point>(pt);
    return p->x;
}
