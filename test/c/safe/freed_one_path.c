/* NEW MEMORY FREED ON ONE PATH ONLY (1.6.32): the join keeps the other path's new memory, which nothing gives back --
   refused as before the freed state, the leak's words */
#include <stdlib.h>
int main(int argc, char **argv) { (void) argv; char *p = malloc(4); if (argc > 5) free(p); return 0; }
