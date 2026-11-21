/* GCC's cleanup attribute refused in clang's words (1.6.8): a function declared after the object */
#include <stdio.h>
int main(void) { int a __attribute__((cleanup(later))) = 1; printf("%d\n", a); return 0; }
static void later(int *p) { printf("bye %d\n", *p); }
