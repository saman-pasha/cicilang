/* A LOCAL RECORD ASSIGNED FROM A STATIC TABLE, ITS POINTER COPIED AND FREED (1.6.35): built, and the run aborted in free */
#include <stdlib.h>
struct tok { const char *s; int n; };
static struct tok toks[2] = { { "a", 1 }, { "b", 2 } };
int main(void) { struct tok t; t = toks[1]; char *q = (char *) t.s; free(q); return 0; }
