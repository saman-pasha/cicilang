/* phase 2: an atomic's object is an integer, a floating number or an enum, and a struct is refused */
#include <atomic.pl>
typedef struct point { int x; } point;
int main(void) {
    atomic<point> p;
    store(p, (point){1});
    return 0;
}
