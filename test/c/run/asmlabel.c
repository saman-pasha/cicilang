/* ASM LABELS (0.194): a declaration's __asm__("sym") names the symbol it stands for -- a function's, a global's, a prototype's
   that its definition takes, the address of a labeled function -- and glibc's strtol stays the old one under gnu17. A label
   is the assembler's name, so one that meets a C name spells the machine's prefix, __USER_LABEL_PREFIX__ (0.247: `_' on a
   Mac, nothing on Linux) */
#include <stdio.h>
#include <stdlib.h>
#define STR_(x) #x
#define STR(x) STR_(x)
#define LABEL(s) STR(__USER_LABEL_PREFIX__) s
extern int twice(int) __asm__(LABEL("my_twice"));
int my_twice(int x) { return 2 * x; }
extern int counter __asm__(LABEL("my_counter"));
int my_counter = 7;
int thrice(int) __asm__(LABEL("my_thrice"));
int thrice(int x) { return 3 * x; }
extern int my_thrice(int);
int main(void) {
  char *end;
  long v = strtol("0b101", &end, 0);
  printf("%d %d %d %d %ld %s\n", twice(21), counter, thrice(2), my_thrice(3), v, end);
  int (*fp)(int) = twice; printf("%d\n", fp(5));
  return 0;
}
