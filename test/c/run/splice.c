#include <stdio.h>
#define ADD(a, b) \  
    ((a) + (b))
// a comment ending in a backslash \
int hidden = 1;
int main(void) { printf("%d\n", ADD(2, 3)); return 0; }
