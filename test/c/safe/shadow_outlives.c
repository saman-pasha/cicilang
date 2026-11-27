/* A BORROW OF AN OUTER OBJECT KEPT PAST THAT OBJECT'S OWN BLOCK (1.6.33): a block inside it declares the name again,
   and the outer object's borrow is its own while that block runs -- it ends with the outer object's block still */
#include <stdio.h>
int main(void) { int *p = NULL; { int x = 1; p = &x; { int x = 2; (void) x; } } printf("%d\n", *p); return 0; }
