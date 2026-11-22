/* lj_volatile_typedef.c (1.6.20): the volatile pointer of lj_volatile_held.c, its type a typedef's -- the qualifier is
   the declaration's, and the local is volatile all the same: the memory that the jump leaves is refused as a leak */
#include <setjmp.h>
#include <stdlib.h>
typedef char *text;
static jmp_buf e;
int main(void) {
    volatile text p = malloc(4);
    if (setjmp(e) != 0) { free(p); return 0; }
    free(p);
    p = malloc(4);
    longjmp(e, 1);
}
