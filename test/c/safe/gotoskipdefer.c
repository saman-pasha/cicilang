// A goto over a defer (0.138): the defer runs at its scope's end on every path, the goto's too, where its operand was
// never set.
#include <stdlib.h>
int f(int k) {
  {
    if (k) goto out;
    own char *p = malloc(4);
    defer(p) { free(p); }
  out:
    ;
  }
  return 0;
}
int main(void) { return f(0); }
