/* A COPY OF A LOCAL RECORD THAT A STATIC TABLE GAVE, ITS POINTER FREED (1.6.35): the second copy holds the table's
   string too -- the copy was refused, `no owner behind: 'g'', before */
#include <stdlib.h>
struct tok { const char *s; int n; };
static struct tok toks[2] = { { "a", 1 }, { "b", 2 } };
int main(void) { struct tok f = toks[0]; struct tok g = f; free((char *) g.s); return 0; }
