/* GLIBC'S C23 REDIRECTS (0.194): under -std=c23 glibc declares strtol and sscanf by asm labels, __isoc23_strtol and
   __isoc23_sscanf, which read a `0b' prefix and `%b'; the old ones stop at the `b' */
#include <stdio.h>
#include <stdlib.h>
int main(void) {
  char *end;
  long v = strtol("0b101", &end, 0);
  unsigned u = 0;
  int n = sscanf("0b110", "%i", (int *) &u);
  unsigned w = 0;
  int m = sscanf("1011", "%b", &w);
  printf("%ld [%s] %d %u %d %u\n", v, end, n, u, m, w);
  return 0;
}
