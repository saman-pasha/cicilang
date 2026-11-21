/* GCC's cleanup attribute refused in clang's words (1.6.8): a function of no parameter */
#include <stdio.h>
static void none(void) { printf("bye\n"); }
int main(void) { int a __attribute__((cleanup(none))) = 1; printf("%d\n", a); return 0; }
