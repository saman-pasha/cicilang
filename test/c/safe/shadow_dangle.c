/* a pointer to a block's local that hides an outer one of the same name, used after the block (0.297): the local's
   end leaves the pointer dangling -- it was built, since the outer one's state answered for the block's */
#include <stdio.h>
int main(void) {
    int v = 1;
    int *q = &v;
    { int v = 2; q = &v; }
    printf("%d\n", *q);
    return 0;
}
