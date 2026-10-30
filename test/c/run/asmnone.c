// An asm operand NAMED `[none]' beside unnamed ones (0.232): `%[none]' is that operand, as clang reads it. The reader
// named an operand without a name `none' until 0.232, and `%[none]' met the first unnamed one, the output
#include <stdio.h>

static int add(int a, int b) {
  int r;
#if defined(__x86_64__)
  asm("movl %1, %0; addl %[none], %0" : "=&r"(r) : "r"(a), [none] "r"(b));
#elif defined(__aarch64__)
  asm("add %w0, %w1, %w[none]" : "=r"(r) : "r"(a), [none] "r"(b));
#endif
  return r;
}

int main(void) {
  printf("%d %d\n", add(5, 7), add(-3, 10));
  return 0;
}
