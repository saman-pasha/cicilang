/* THE FRAME'S MEMORY RETURNED (1.6.54): alloca's block ends with its function, as a local's storage does -- it was the
   check's `plain pointer not consumed', and a borrow of the frame leaves the function as a local's address would */
#include <alloca.h>
char *f(void) { char *p = (char *) alloca(4); return p; }
int main(void) { return f() != 0; }
