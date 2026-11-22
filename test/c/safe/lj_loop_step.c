/* lj_loop_step.c (1.6.17): a pointer stepped in a loop after a call that may jump -- in the next pass the jump comes after
   the step, so the pointer's value after the jump is not known (C17 7.13.2.1/3): clang -O2's build prints `stop at 0'
   where clang -O0's prints `stop at 2'. Refused at the jump */
#include <setjmp.h>
#include <stdio.h>
static jmp_buf env;
static void step(const char *s) { if (*s == '!') longjmp(env, 1); }
int main(void) {
    const char *text = "ab!c";
    const char *s = text;
    if (setjmp(env) != 0) { printf("stop at %d\n", (int)(s - text)); return 0; }
    while (*s) { step(s); s++; }
    return 0;
}
