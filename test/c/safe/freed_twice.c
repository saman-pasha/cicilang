/* A PLAIN POINTER FREED TWICE (1.6.32): its free leaves it freed, and a second free reads it -- it was built, and
   the run aborted in free (`double free detected') */
#include <stdlib.h>
int main(void) { char *p = malloc(8); free(p); free(p); return 0; }
