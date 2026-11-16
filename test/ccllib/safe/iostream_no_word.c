/* phase 1d: a value whose type has no form of `<<' is refused by name */
#include <iostream.pl>
typedef struct point { int x; } point;
int main(void) {
    point p = { 1 };
    cout << p;
    return 0;
}
