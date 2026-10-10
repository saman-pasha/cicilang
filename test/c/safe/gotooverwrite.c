// A backward goto (0.133): its state joins the label's on a second walk, where the owner is live and is taken again.
#include <stdlib.h>
int f(int n) {
  own char *q = 0;
  int i = 0;
again:
  q = malloc(8);
  if (++i < n) goto again;
  free(q);
  return i;
}
int main(void) { return f(2); }
