/* lj_stepped.c (1.6.17): a pointer stepped between a setjmp and a longjmp to it -- its state is the setjmp's, a borrow of
   the same text, but its value after the jump is not known (C17 7.13.2.1/3): clang -O2's build prints `a' where clang
   -O0's prints `b'. Refused at the jump */
#include <setjmp.h>
#include <stdio.h>
static jmp_buf env;
static void check(const char *s) { if (*s == 'b') longjmp(env, 1); }
int main(void) {
    const char *text = "abc";
    const char *s = text;
    if (setjmp(env)) { printf("%c\n", *s); return 0; }
    s++;
    check(s);
    return 0;
}
