/* A POINTER MEMBER OF A GLOBAL STRUCT FREED THROUGH A LOCAL (1.6.31) -- it was built, and the run aborted in free */
#include <stdlib.h>
static struct { char *name; int n; } cfg = { "abc", 3 };
int main(void) { char *p = cfg.name; free(p); return cfg.n - 3; }
