/* A GNU mode (no -std: gnu17, 0.214): `linux' and `unix' are predefined and __STRICT_ANSI__ is not, glibc declares
   POSIX's and BSD's names, and `typeof' and `asm' are GNU's keywords, `asm' the label's */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int gm_seven(void) asm("gm_impl");
int gm_impl(void) { return 7; }
int main(void) {
  int a = 5;
  typeof(a) b = a + 1;
  char *d = strdup("posix");
#ifdef __STRICT_ANSI__
  printf("strict\n");
#else
  printf("gnu %d %d %d %s %.4f %d\n", linux, unix, b, d, M_PI, gm_seven());
#endif
  free(d);
  return 0;
}
