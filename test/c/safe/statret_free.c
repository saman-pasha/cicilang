/* STATIC STORAGE FREED (0.294): the result of a function whose every return is static storage, kept in a local */
#include <stdlib.h>
static int table[4];
static int *row(int i) { return table + i; }
int main(void) { int *p = row(1); free(p); return 0; }
