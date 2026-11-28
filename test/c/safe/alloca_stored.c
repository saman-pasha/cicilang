/* THE FRAME'S MEMORY STORED WHERE IT OUTLIVES ITS FUNCTION (1.6.54): a global's field takes a borrow of the frame, which
   ends with main's frame -- the check follows no such slot */
#include <alloca.h>
struct S { char *s; };
struct S g;
int main(void) { char *p = (char *) alloca(4); g.s = p; return 0; }
