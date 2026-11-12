/* A FUNCTION THAT RETURNS STATIC STORAGE ON ONE ROAD AND NEW MEMORY ON ANOTHER answers new memory (0.294) */
#include <stdlib.h>
static int table[4];
static int *mixed(int i) { if (i) return table + i; return malloc(4 * sizeof(int)); }
int main(void) { int *p = mixed(1); p[0] = 1; return p[0]; }
