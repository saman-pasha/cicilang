/* STATIC STORAGE GIVEN TO AN OWNER (0.294): a string literal is no owner's memory */
#include <stdlib.h>
int main(void) { own char *o = "abc"; free(o); return 0; }
