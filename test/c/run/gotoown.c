// A goto followed by the safe part (0.133): `goto out;' to a cleanup label that frees the owner, from a nested block;
// a retry loop that frees its owner and jumps back to take another; a label reached by gotos alone.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int work(int k) {
  own char *p = malloc(16);
  int r = 0;
  if (!p) return -1;
  if (k > 2) {
    r = 1;
    goto out;
  }
  strcpy(p, "ok");
  r = 2 + (int) strlen(p);
out:
  free(p);
  return r;
}
int retry(int n) {
  int tries = 0;
  own char *q = 0;
again:
  q = malloc(8);
  tries++;
  if (tries < n) {
    free(q);
    goto again;
  }
  free(q);
  return tries;
}
int only(int k) {
  int r = 0;
  if (k) goto a;
  goto b;
a:
  r = 1;
  goto c;
b:
  r = 2;
c:
  return r;
}
int main(void) {
  printf("%d %d %d %d %d\n", work(1), work(5), retry(3), only(1), only(0));
  return 0;
}
