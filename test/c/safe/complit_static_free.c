/* C23'S STATIC COMPOUND LITERAL FREED (1.6.31): static storage, which free does not consume -- the literal was
   the block's, its storage class dropped, and the run aborted in free */
#include <stdlib.h>
int main(void) { free(&(static int){ 1 }); return 0; }
