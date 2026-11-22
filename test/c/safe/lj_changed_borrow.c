/* lj_changed_borrow.c (1.6.17): a pointer of the setjmp's frame given another object between the setjmp and the jump --
   after the jump its value is not known (C17 7.13.2.1/3), and the second return reads it: refused at the jump */
#include <setjmp.h>
#include <stdio.h>
static jmp_buf env;
int main(void) {
    int a = 1, b = 2;
    int *q = &a;
    if (setjmp(env)) { printf("%d\n", *q); return 0; }
    q = &b;
    longjmp(env, 1);
}
