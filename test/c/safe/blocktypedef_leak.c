/* blocktypedef_leak.c (1.6.2): a block's typedef of a pointer type is its block's, and the safe part sees the pointer
   that a local of that type holds -- new memory never freed. Through 1.6.1 the check met the first block's typedef of
   the name, an int, and refused the initializer as an integer's */
#include <stdlib.h>
int main(void) {
    { typedef int P; P k = 0; (void)k; }
    { typedef char *P; P s = malloc(4); }
    return 0;
}
