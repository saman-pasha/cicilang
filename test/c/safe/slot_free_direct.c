/* AN ELEMENT OF A GLOBAL TABLE OF LITERALS FREED (1.6.31) -- it was built, and the run aborted in free */
#include <stdlib.h>
static char *names[] = { "a", "b" };
int main(void) { free(names[1]); return 0; }
