/* lj_fn_global.c (1.6.17): a file-scope pointer to a function that may longjmp: refused at its declaration */
#include <setjmp.h>
static jmp_buf env;
static void jump(void) { longjmp(env, 1); }
static void (*hook)(void) = jump;
int main(void) { if (setjmp(env)) return 0; hook(); return 1; }
