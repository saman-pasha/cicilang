/* C23's #__VA_OPT__(...): the group substituted and pasted, then stringized; "" where the variadic arguments have no
   token; clang's and gcc's output */
#include <stdio.h>
#define SO(a, ...) #__VA_OPT__(a  __VA_ARGS__)
#define SO2(a, ...) #__VA_OPT__(<a>__VA_ARGS__ x)
#define SO3(a, ...) # __VA_OPT__( a ## __VA_ARGS__ )
int main(void) {
  puts(SO(1, 2   3));
  puts(SO(1));
  puts(SO2(1, 2));
  puts(SO2(1,));
  puts(SO3(1, 2));
  puts(SO3(1));
  return 0;
}
