/* GCC's weak, alias and section (1.6.40): a weak definition and a weak object, a weak declaration that nothing defines --
   its address null --, an alias of a function and of an object, two objects and a function in sections of their own, the
   section's objects counted by the linker's __start_ and __stop_ symbols; each as clang has it */
#include <stdio.h>
__attribute__((weak)) int wf(void) { return 1; }
__attribute__((weak)) void missing(void);
extern int missing_obj __attribute__((weak));
int g_target(int x) { return x * 2; }
int g_alias(int x) __attribute__((alias("g_target")));
__attribute__((section("mysec"))) int in_sec = 5;
__attribute__((section("mysec"))) int in_sec2 = 6;
__attribute__((section(".text.hot"))) int hot(void) { return 3; }
__attribute__((section("fsec"))) int in_fsec(void) { return 4; }
__attribute__((weak)) int wv = 7;
int t_obj = 11;
extern int a_obj __attribute__((alias("t_obj")));
extern int __start_mysec, __stop_mysec;
extern char __start_fsec, __stop_fsec;
int main(void) {
  printf("%d %d %d %d %d %d %d %d\n", wf(), missing ? 1 : 0, &missing_obj ? 1 : 0, g_alias(4), in_sec + in_sec2, hot(), wv, a_obj);
  printf("mysec holds %d ints, fsec a function: %d %d\n", (int)(&__stop_mysec - &__start_mysec), &__stop_fsec > &__start_fsec, in_fsec());
  return 0;
}
