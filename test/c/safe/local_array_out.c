/* A LOCAL'S ARRAY RETURNED BY ITS NAME (1.6.35; C17 6.3.2.1/3: it decays to a pointer to its first element): the
   frame ends at the return -- built, where clang warns `address of stack memory associated with local variable 'buf'
   returned', and so was a local record's array member; through a pointer local each was refused */
#include <stdio.h>
static const char *f(void) { char buf[8] = "x"; return buf; }
int main(void) { puts(f()); return 0; }
