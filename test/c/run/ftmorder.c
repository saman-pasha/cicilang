/* 0.239: a header is read under the program's configuration AT ITS OWN #include, as clang reads it: <string.h> before
   the __STDC_WANT_LIB_EXT2__ definition sees none, <stdio.h> after it sees it (glibc's libc-header-start.h at each) */
#include <stdlib.h>
#include <string.h>
static const int before = __GLIBC_USE_LIB_EXT2;
#define __STDC_WANT_LIB_EXT2__ 1
#include <stdio.h>
static const int after = __GLIBC_USE_LIB_EXT2;
int main(void) {
  char *s = 0;
  int n = asprintf(&s, "%d %d", before, after);
  printf("%s %d\n", s, n);
  free(s);
  return 0;
}
