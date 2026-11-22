/* noreturn_def_end.c (1.6.17): a definition marked _Noreturn after a declaration with no mark: the definition's own mark
   holds, and its end is refused in clang's words */
#include <stdlib.h>
void stop(int c);
int main(void) { stop(1); }
_Noreturn void stop(int c) { if (c > 0) exit(c); }
