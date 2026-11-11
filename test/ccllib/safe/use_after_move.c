/* <vector.pl>: `w := v;' moves, as every object of an instance's type does; size(v) after it reads a vector that was
   moved from (0.274; autodrop's rule of 0.262) */
#include <stdio.h>
#include <vector.pl>
int main(void) {
    v := [int; 1, 2, 3];
    w := v;
    printf("%zu %zu\n", size(w), size(v));
    return 0;
}
