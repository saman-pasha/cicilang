/* An ISO mode (-std=c17, 0.214): __STRICT_ANSI__ is predefined, and `linux' and `unix' are not; glibc declares ISO C's
   names alone, so POSIX's `strdup' and `fileno' and BSD's `M_PI' are the program's to take, and `typeof' and `asm' are
   names of the program's, not GNU's keywords; <float.h> has C17's names, not C23's */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <float.h>
static int strdup = 1;
static int fileno = 2;
static int M_PI = 3;
static int typeof = 4;
static int asm = 5;
static int linux = 6, unix = 7;
static int twice(int typeof) { return typeof * 2; }
int main(void) {
#ifdef __STRICT_ANSI__
  printf("strict %d\n", __STRICT_ANSI__);
#else
  printf("not strict\n");
#endif
  printf("%d %d %d %d %d %d %d\n", strdup, fileno, M_PI, typeof, asm, linux, unix);
  printf("%d %.1f\n", twice(typeof), sqrt(16.0));
#if defined(FLT_NORM_MAX) || defined(FLT_SNAN)
  printf("C23's float.h\n");
#else
  printf("C17's float.h\n");
#endif
#ifdef FLT_TRUE_MIN
  printf("C11's float.h\n");
#endif
  return 0;
}
