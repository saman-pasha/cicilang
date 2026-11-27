/* A POINTER OF A RECORD THAT ITS FUNCTION FILLED WITH A LITERAL AND RETURNED, FREED (1.6.35): the record's string is
   the literal -- the call was refused, `no owner behind', before */
#include <stdlib.h>
struct tok { const char *s; int n; };
static struct tok made(int n) { struct tok t = { "lit", n }; return t; }
int main(void) { struct tok t = made(3); free((char *) t.s); return 0; }
