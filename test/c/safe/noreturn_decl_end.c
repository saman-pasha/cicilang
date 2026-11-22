/* noreturn_decl_end.c (1.6.17): the mark of an earlier declaration holds for the definition, and its end is refused */
#include <stdlib.h>
static void stop(int c) __attribute__((noreturn));
int main(void) { stop(1); }
static void stop(int c) { if (c > 0) exit(c); }
