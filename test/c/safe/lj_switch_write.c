/* lj_switch_write.c (1.6.17): a pointer given a value in a case's block that a break leaves -- the path goes on past the
   switch to a call that may jump, so the pointer's value after the jump is not known; refused at the jump */
#include <setjmp.h>
#include <stdio.h>
static jmp_buf env;
static void check(const char *s) { if (*s == 'b') longjmp(env, 1); }
int main(int argc, char **argv) {
    (void)argv;
    const char *text = "abc";
    const char *s = text;
    if (setjmp(env)) { printf("%c\n", *s); return 0; }
    switch (argc) {
    case 1: { s = text + 1; break; }
    default: break;
    }
    check(s);
    return 0;
}
