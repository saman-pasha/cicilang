/* the address of a pointer parameter held by a local and handed to a call inside its function: accepted (0.219) */
#include <stdio.h>
static int deref2(int **pp) { return **pp; }
static int f(int *p) { int **pp = &p; return deref2(pp) + **pp; }
int main(void) { int x = 4; printf("%d\n", f(&x)); return 0; }
