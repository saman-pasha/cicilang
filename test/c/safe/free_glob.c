/* STATIC STORAGE FREED (0.294): a plain local given a place in a global array is a borrow that nothing ends */
#include <stdlib.h>
static int table[4];
int main(void) { int *p = table + 1; free(p); return 0; }
