/* GCC's mode attribute, a type of a machine mode's size, refused by name in the program's text (1.6.8) */
#include <stdio.h>
typedef int i8 __attribute__((mode(QI)));
int main(void) { i8 a = 127; a++; printf("%zu %d\n", sizeof(i8), a); return 0; }
