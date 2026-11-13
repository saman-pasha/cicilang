/* <memory.pl>: make_unique<T> takes a value of T: an int is no point (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    unique_ptr<point> p = make_unique<point>(5);
    return p->x;
}
