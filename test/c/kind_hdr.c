/* A FUNCTION AFTER A HEADER'S OBJECT OF ITS NAME (0.298; the finding of a program over 0.284): `look(t, i)' read the
   function's code as the table. Refused at the function's line */
#include "kind_hdr.h"
static unsigned look(const unsigned *a, unsigned i) { return a[i]; }
static unsigned t(unsigned i) { return look(t, i); }
int main(void) { return (int)t(1); }
