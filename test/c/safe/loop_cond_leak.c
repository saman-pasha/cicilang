/* A LOOP'S CONDITION EVALUATED AGAIN AFTER A PASS THAT KEEPS ITS MEMORY (1.6.34; C17 6.8.5/4): the next pass's
   assignment throws away the block of the last one */
#include <stdlib.h>
int main(void) { char *q; int n = 0; while ((q = malloc(4)) != NULL) { if (++n > 3) { free(q); break; } } return 0; }
