/* AN ARRAY MEMBER OF A LOCAL RECORD COPIED FROM STATIC STORAGE, RETURNED THROUGH A POINTER (1.6.35): the array is the
   local's own storage, no static one, and it ends with the function -- clang warns, `address of stack memory associated
   with local variable 'h' returned' */
#include <stdio.h>
struct named { char name[8]; const char *tag; };
static struct named names[2] = { { "one", "first" }, { "two", "second" } };
static const char *name_of(int i) { struct named h = names[i]; const char *p = h.name; return p; }
int main(void) { puts(name_of(1)); return 0; }
