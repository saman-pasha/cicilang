/* NEW MEMORY FREED ON ONE PATH ONLY, THEN FREED AGAIN (1.6.34): the join is maybe freed, and the second free a use
   after free on the first path -- it was built, and with an argument count past 5 the run aborted in free */
#include <stdlib.h>
int main(int argc, char **argv) { (void) argv; char *p = malloc(4); if (argc > 5) free(p); free(p); return 0; }
