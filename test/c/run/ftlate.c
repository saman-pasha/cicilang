/* A feature-test macro defined after the file's first system #include (0.215): a __STDC_WANT_* name reaches the headers
   included after it, which glibc's headers ask at each inclusion; a features.h name counts where the first header that
   reads the C library is included, as in clang and gcc -- <stdarg.h> reads none of it, so _POSIX_C_SOURCE after it
   gives strdup and fileno, and _DEFAULT_SOURCE after <string.h> gives no M_PI. Each was missed: the headers were read
   under what the file defined before its first system #include */
#include <stdarg.h>
#define _POSIX_C_SOURCE 200809L
#include <string.h>
#define __STDC_WANT_LIB_EXT2__ 1
#include <stdio.h>
#define __STDC_WANT_IEC_60559_TYPES_EXT__ 1
#include <stdlib.h>
#define _DEFAULT_SOURCE 1
#include <math.h>
#ifdef M_PI
#define FT_PI 1
#else
#define FT_PI 0
#endif
int main(void) {
  char *d = strdup("late"), *s = 0, b[32];
  int n = asprintf(&s, "%s %d", d, fileno(stdout));
  strfromf32(b, sizeof b, "%g", (_Float32) 1.5f);
  printf("%s %d %s %d\n", s, n, b, FT_PI);
  free(d);
  free(s);
  return 0;
}
