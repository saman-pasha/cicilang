/* GCC's cleanup attribute refused in clang's words (1.6.8): a name that nothing declares */
#include <stdio.h>
int main(void) { int a __attribute__((cleanup(nowhere))) = 1; printf("%d\n", a); return 0; }
