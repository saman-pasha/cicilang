/* STATIC STORAGE GIVEN TO AN OWNER (0.294): a global's address is no owner's memory */
#include <stdlib.h>
static int g;
int main(void) { own int *o = &g; free(o); return 0; }
