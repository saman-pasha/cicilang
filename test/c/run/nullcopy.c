#include <stdio.h>
int main(void) { int *p = 0; int *q = p; printf("%d\n", q == 0); return 0; }
