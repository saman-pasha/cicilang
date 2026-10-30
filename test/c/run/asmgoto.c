// GNU's `asm goto' (0.231), lowered as clang lowers it, a `callbr': a jump to a C label by the template's `%l1' and
// `%l[name]', with no output and with one, whose value holds on both paths; and out of a block whose local the label
// does not see
#include <stdio.h>

static int test(int x) {
#if defined(__x86_64__)
  asm goto("testl %0, %0; jz %l1" : : "r"(x) : "cc" : zero);
#elif defined(__aarch64__)
  asm goto("cbz %w0, %l1" : : "r"(x) : "cc" : zero);
#endif
  return 1;
zero:
  return 0;
}

static int pick(int x) {
  int y;
#if defined(__x86_64__)
  asm goto("movl %1, %0; testl %1, %1; jz %l[none]" : "=r"(y) : "r"(x) : "cc" : none);
#elif defined(__aarch64__)
  asm goto("mov %w0, %w1; cbz %w1, %l[none]" : "=r"(y) : "r"(x) : "cc" : none);
#endif
  return y * 2;
none:
  return y - 1;
}

static int twice(int a, int b) {
  int n = 0;
  {
    int k = a + b;
#if defined(__x86_64__)
    asm goto("cmpl %1, %0; je %l2" : : "r"(a), "r"(b) : "cc" : same);
#elif defined(__aarch64__)
    asm goto("cmp %w0, %w1; b.eq %l2" : : "r"(a), "r"(b) : "cc" : same);
#endif
    n = k;
  }
  return n;
same:
  return -n - 1;
}

int main(void) {
  printf("%d %d %d %d\n", test(0), test(5), pick(0), pick(7));
  printf("%d %d\n", twice(2, 3), twice(4, 4));
  return 0;
}
