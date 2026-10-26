/* `$' in a name, an object's, a function's and a macro's (C17 6.4.2.1/3's implementation-defined characters), as
   clang and gcc take it; and a name that begins with it */
#include <stdio.h>
#define M$ 3
#define $twice(x) ((x) * 2)
static int a$b = 2;
static int $lead(int v) { return v + 1; }
int main(void) {
  int sum$ = a$b + M$ + $twice($lead(1));
  printf("%d %d\n", sum$, $lead(a$b));
  return sum$ - 9;
}
