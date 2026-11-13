/* <memory.pl>: the own pointer that release gives is the program's to free (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    point pt = {1, 2};
    unique_ptr<point> p = make_unique<point>(pt);
    own point *r = release(p);
    return r->x;
}
