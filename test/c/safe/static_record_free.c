/* A POINTER OF A RECORD THAT A FUNCTION ANSWERS FROM STATIC STORAGE, FREED (1.6.35): pick's every return is a static
   table's element, so the record's string is the table's -- the call was refused, `no owner behind', before */
#include <stdlib.h>
struct tok { const char *s; int n; };
static struct tok toks[2] = { { "a", 1 }, { "b", 2 } };
static struct tok pick(int i) { return toks[i]; }
int main(void) { struct tok t = pick(1); free((char *) t.s); return 0; }
