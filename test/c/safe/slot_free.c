/* A POINTER READ OUT OF A GLOBAL TABLE OF LITERALS, FREED (1.6.31): the plain slot of a global object holds static
   storage alone -- it was built, and the run aborted in free */
#include <stdlib.h>
static char *names[] = { "a", "b" };
int main(void) { char *p = names[1]; free(p); return 0; }
