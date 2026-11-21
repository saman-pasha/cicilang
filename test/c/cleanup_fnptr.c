/* GCC's cleanup attribute refused in clang's words (1.6.8): a pointer to a function, no function */
#include <stdio.h>
static void bye(int *p) { printf("bye %d\n", *p); }
int main(void) { void (*fp)(int *) = bye; int a __attribute__((cleanup(fp))) = 1; printf("%d\n", a); return 0; }
