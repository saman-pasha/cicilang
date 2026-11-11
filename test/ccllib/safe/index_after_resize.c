/* <vector.pl>: &v[0] is a borrow of the buffer, tied to the vector, and resize may replace the buffer; over v[1] = 5,
   which replaces nothing, the borrow is kept (0.274) */
#include <stdio.h>
#include <vector.pl>
int main(void) {
    v := [int; 1, 2, 3];
    int *p = &v[0];
    v[1] = 5;
    *p = 7;
    resize(v, 100);
    printf("%d\n", *p);
    return 0;
}
