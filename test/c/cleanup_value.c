/* GCC's cleanup attribute refused in clang's words (1.6.8): a function whose parameter is no pointer */
#include <stdio.h>
static void val(int p) { printf("bye %d\n", p); }
int main(void) { int a __attribute__((cleanup(val))) = 1; printf("%d\n", a); return 0; }
