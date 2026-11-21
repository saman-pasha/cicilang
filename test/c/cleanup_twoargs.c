/* GCC's cleanup attribute refused in clang's words (1.6.8): two arguments */
#include <stdio.h>
static void bye(int *p) { printf("bye %d\n", *p); }
int main(void) { int a __attribute__((cleanup(bye, bye))) = 1; printf("%d\n", a); return 0; }
