/* GCC's cleanup attribute refused in clang's words (1.6.8): no argument */
#include <stdio.h>
int main(void) { int a __attribute__((cleanup)) = 1; printf("%d\n", a); return 0; }
