/* STATIC STORAGE FREED (0.294): a plain local given new memory, freed, then given a global array by an assignment */
#include <stdlib.h>
static int table[4];
int main(void) { int *p = malloc(4 * sizeof(int)); free(p); p = table; free(p); return 0; }
