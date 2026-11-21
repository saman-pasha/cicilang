/* GCC's cleanup attribute refused in clang's words (1.6.8): a name of an object, no function */
#include <stdio.h>
int main(void) { int k = 0; int a __attribute__((cleanup(k))) = 1; printf("%d %d\n", a, k); return 0; }
