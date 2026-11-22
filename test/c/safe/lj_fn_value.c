/* lj_fn_value.c (1.6.17): a function that may longjmp, handed to signal() as a value: its jump would land where no call of
   it is followed -- refused */
#include <setjmp.h>
#include <signal.h>
static jmp_buf env;
static void handler(int s) { longjmp(env, s); }
int main(void) { if (setjmp(env)) return 0; signal(SIGINT, handler); raise(SIGINT); return 1; }
