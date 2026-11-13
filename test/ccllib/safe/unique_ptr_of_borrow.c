/* <memory.pl>: a unique_ptr is made of an own pointer, which it frees: the address of a local is none (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    point pt = {1, 2};
    unique_ptr<point> p = &pt;
    return p->x;
}
