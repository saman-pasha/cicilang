/* C23 made bool, true and false keywords (6.4.1, 7.18): after <stdbool.h> `true' is still the keyword, a bool of one
   byte, and `bool' the type; C17's header made `true' the int 1 (0.214: it did at C23 too) */
#include <stdbool.h>
#include <stdio.h>
int main(void) {
  bool b = true;
  printf("%d %zu %zu %d\n", _Generic(true, bool: 1, int: 2, default: 0), sizeof(true), sizeof b, __bool_true_false_are_defined);
  printf("%d %d\n", _Generic(false, bool: 1, default: 0), true + true);
  return 0;
}
