// A goto followed by the safe part (0.133): on the jump to `out' the owner is still live, and the return leaks it.
#include <stdlib.h>
int f(int k) {
  own char *p = malloc(4);
  if (k) goto out;
  free(p);
out:
  return 0;
}
int main(void) { return f(0); }
