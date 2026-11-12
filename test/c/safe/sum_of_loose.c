/* A SUM OF A LOOSE POINTER IS A BORROW OF IT (0.299): the rule that takes a sum of a pointer that holds no memory the
   check follows as no new memory leaves this one as it was -- `p' is new memory, never freed */
#include <stdlib.h>
int main(void) { char *p = malloc(4); if (!p) return 2; char *q = p + 1; return q == 0; }
