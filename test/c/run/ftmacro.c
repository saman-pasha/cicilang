/* A PROGRAM'S FEATURE-TEST MACROS (POSIX 2.2.1, glibc's features.h; 0.214): defined before the first system #include,
   by the file and by a header of its own, they configure every header's read, as -D does. Under -std=c17 glibc
   declares ISO C's names alone; _POSIX_C_SOURCE gives strdup and fileno, _DEFAULT_SOURCE M_PI and htobe32. The
   headers were read under the predefined macros alone: strdup was undeclared */
#define _POSIX_C_SOURCE 200809L
#include "ftmacro.h"
#include <endian.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(void) {
  char *d = strdup("posix");
  printf("%s %.4f %x %d\n", d, M_PI, (unsigned) htobe32(0x01020304u), fileno(stdout));
  free(d);
  return 0;
}
