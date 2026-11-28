/* GCC's alias in C (1.6.58): its function type is the signature's types alone, as clang writes it -- narrow integers and an
   sret, where `(i8 signext, i64)' was LLVM's `argument attributes invalid in function type' --, of a static function, of an
   alias, of an object, and before its target */
#include <stdio.h>
int later(int x) __attribute__((alias("target_after")));
int deep(char c, long n) { return c + (int) n; }
int deepa(char, long) __attribute__((alias("deep")));
short sh(short s) { return s + 1; }
short sha(short) __attribute__((alias("sh")));
_Bool yes(_Bool b) { return !b; }
_Bool yesa(_Bool) __attribute__((alias("yes")));
struct Big { long a, b, c; };
struct Big mk(int k) { struct Big b = { k, k + 1, k + 2 }; return b; }
struct Big mka(int) __attribute__((alias("mk")));
static int s(int x) { return x * 4; }
int sa(int) __attribute__((alias("s")));
int sb(int) __attribute__((alias("sa")));
int target_after(int x) { return x + 5; }
int v = 3;
extern int va __attribute__((alias("v")));
int main(void) {
  struct Big b = mka(4);
  printf("%d %d %d %ld %d %d %d %d\n", deepa('a', 3), sha(9), yesa(0), b.c, sa(2), sb(3), later(1), va);
  return 0;
}
