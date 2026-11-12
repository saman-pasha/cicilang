/* STATIC STORAGE FREED (0.294): a global array freed by its name */
#include <stdlib.h>
static int table[4];
int main(void) { free(table); return 0; }
