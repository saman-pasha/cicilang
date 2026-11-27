/* A GLOBAL PLAIN POINTER FREED (1.6.31): it holds static storage -- it was built, and the run aborted in free */
#include <stdlib.h>
static char *gp = "x";
int main(void) { free(gp); return 0; }
