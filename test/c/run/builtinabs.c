/* clang's integer absolute values, `__builtin_abs', `__builtin_labs' and `__builtin_llabs': LLVM's `llvm.abs' since
   1.6.21, where they were calls of the C library's abs, labs and llabs -- the operand brought to the parameter's type
   (an int, a long, a long long), the result of that type */
#include <stdio.h>
int main(void) {
  volatile int a = -4, z = 0;
  volatile long b = -7000000000L;
  volatile long long c = -9;
  volatile short s = -3;
  volatile unsigned u = 5;
  printf("%d %d %ld %lld\n", __builtin_abs(a), __builtin_abs(z), __builtin_labs(b), __builtin_llabs(c));
  printf("%d %d %ld\n", __builtin_abs(s), __builtin_abs(-a), __builtin_labs(a));
  printf("%d %d %d\n", (int) sizeof(__builtin_abs(c)), (int) sizeof(__builtin_labs(s)), (int) sizeof(__builtin_llabs(s)));
  printf("%d %d %d\n", _Generic(__builtin_abs(c), int: 1, default: 0), _Generic(__builtin_labs(a), long: 1, default: 0),
         _Generic(__builtin_llabs(a), long long: 1, default: 0));
  printf("%d\n", __builtin_abs((int) u - 9));
  return 0;
}
