/* A LOCAL RECORD'S ARRAY MEMBER RETURNED (1.6.35): it decays to a pointer into the record, which the return ends --
   built, and the caller printed what the dead frame held */
#include <stdio.h>
struct named { char name[8]; int n; };
static const char *f(void) { struct named h = { "x", 1 }; return h.name; }
int main(void) { puts(f()); return 0; }
