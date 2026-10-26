/* <assert.h> DEFINES assert BY NDEBUG AS IT STANDS AT EACH INCLUSION (C17 7.2/1; 0.214): defined, assert is ((void)0)
   and its operand is not evaluated; undefined and the header included again, assert checks again. NDEBUG went
   unseen, and the first assert(0) aborted */
#include <stdio.h>
#define NDEBUG
#include <assert.h>
static int calls;
static int touch(void) { return ++calls; }
static void off(void) { assert(0); assert(touch()); puts("off"); }
#undef NDEBUG
#include <assert.h>
static void on(int x) { assert(x == 1); assert(touch()); puts("on"); }
int main(void) {
  off();
  on(1);
  printf("%d\n", calls);
  return 0;
}
