/* AN ELEMENT OF A GLOBAL TABLE GIVEN TO AN OWNER (1.6.31): static storage, which no owner takes -- it was built, and
   the run aborted in free */
#include <stdlib.h>
static char *names[] = { "a", "b" };
int main(void) { own char *o = names[0]; free(o); return 0; }
