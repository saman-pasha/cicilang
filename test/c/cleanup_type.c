/* GCC's cleanup attribute refused in clang's words (1.6.8): a function whose parameter points to another type */
#include <stdio.h>
static void byed(double *p) { printf("bye %f\n", *p); }
int main(void) { int a __attribute__((cleanup(byed))) = 1; printf("%d\n", a); return 0; }
