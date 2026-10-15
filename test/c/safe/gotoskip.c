// A goto over an owner's declaration (0.138): on the goto's path p was never set, and the free after the label would
// free garbage.
#include <stdlib.h>
int f(int k) {
  if (k) goto use;
  {
    own char *p = malloc(4);
  use:
    free(p);
  }
  return 0;
}
int main(void) { return f(0); }
