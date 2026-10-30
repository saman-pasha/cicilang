/* a block held by a plain pointer, an int computed from it returned: refused (0.238; the return took the block over) */
#include <stdlib.h>
int main(void) { int *p = malloc(sizeof(int)); *p = 1; return p[0] - 1; }
