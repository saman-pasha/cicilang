/* A POINTER OF A LOCAL RECORD COPIED FROM A STATIC TABLE, FREED (1.6.35): it was a pointer read out of a plain slot, which
   free takes -- built, and the run aborted in free, `invalid pointer' */
#include <stdlib.h>
struct tok { const char *s; int n; };
static struct tok toks[2] = { { "a", 1 }, { "b", 2 } };
int main(void) { struct tok t = toks[1]; free((char *) t.s); return 0; }
