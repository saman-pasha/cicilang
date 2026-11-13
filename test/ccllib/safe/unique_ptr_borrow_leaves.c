/* <memory.pl>: the place that get gives does not leave the function that holds the unique_ptr (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
static point *leak(void) {
    point pt = {1, 2};
    unique_ptr<point> p = make_unique<point>(pt);
    return get(p);
}
int main(void) { return leak()->x; }
