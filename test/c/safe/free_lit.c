/* STATIC STORAGE FREED (0.294): a plain local given a string literal is a borrow that nothing ends; its free was
   built, and the run aborted in free */
#include <stdlib.h>
int main(void) { const char *s = "abc"; free((void *) s); return 0; }
