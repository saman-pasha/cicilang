/* A SECOND DEFINITION IN A HEADER'S ARM THAT A LATE HEADER MAKES LIVE (1.6.7): the computed #include of <limits.h> is
   ready only when the file is run again, and only then is INT_MAX defined at redef_late.h's #ifdef, so the lines that
   the second run keeps are the header's: f is defined there and again in the file, refused at the file's line */
#define REDEF_LIMITS <limits.h>
#include REDEF_LIMITS
#include "redef_late.h"
static int f(void) { return 2; }
int main(void) { return f(); }
