/* A function that a block declares, defined in another unit (1.6.14; C17 6.2.1/4, 6.7/7): its name answers the call in
 * the block. Through 1.6.13 the call was `call to undeclared function 'twice'', no declaration at file scope naming it */
#include <stdio.h>
int main(void) {
    int twice(int);
    extern int seen;
    printf("%d %d\n", twice(21), seen);
    return 0;
}
