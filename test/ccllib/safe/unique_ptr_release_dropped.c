/* <memory.pl>: the own pointer that release gives, thrown away, leaks its block (the safe part's new memory thrown
   away) (0.309) */
#include <memory.pl>
typedef struct point { int x, y; } point;
int main(void) {
    point pt = {1, 2};
    unique_ptr<point> p = make_unique<point>(pt);
    release(p);
    return 0;
}
