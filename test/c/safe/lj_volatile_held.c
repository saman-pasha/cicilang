/* lj_volatile_held.c (1.6.20): a volatile pointer that holds new memory at the setjmp, freed and given new memory again
   before the jump -- C keeps a volatile's value across the jump, so it is no key changed since the setjmp; the walk of
   the second return starts from the setjmp's state, and the memory that the jump leaves is refused as a leak */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf e;
int main(void) {
    char *volatile p = malloc(4);
    if (setjmp(e) != 0) { free(p); return 0; }
    free(p);
    p = malloc(4);
    longjmp(e, 1);
}
