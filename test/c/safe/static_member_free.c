/* an array member of a static struct freed (0.297): static storage -- it was built, and the run aborted in `free' */
#include <stdlib.h>
static struct { char name[8]; int n; } cfg = { "abc", 3 };
int main(void) { char *p = cfg.name; free(p); return 0; }
