/* STATIC STORAGE HANDED TO AN OWN PARAMETER (0.294): the callee frees it */
#include <stdlib.h>
static void take(own char *p) { free(p); }
int main(void) { take("abc"); return 0; }
