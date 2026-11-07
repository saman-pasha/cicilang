/* GCC's __builtin_types_compatible_p in C (0.258): tags, typedefs, enumerations and their integer types, pointers, functions, arrays */
#include <stdio.h>
struct S { int a; };
struct T { int a; };
enum E { X };
enum F { Z = -1 };
typedef struct S SS;
int f(int x) { return x; }
int main(void) {
  int r[] = { __builtin_types_compatible_p(struct S, SS), __builtin_types_compatible_p(struct S, struct T),
              __builtin_types_compatible_p(enum E, unsigned int), __builtin_types_compatible_p(enum E, int),
              __builtin_types_compatible_p(enum F, int), __builtin_types_compatible_p(enum E, enum F),
              __builtin_types_compatible_p(int *, const int *), __builtin_types_compatible_p(int * const, int *),
              __builtin_types_compatible_p(int (*)(int), __typeof__(&f)), __builtin_types_compatible_p(long, long long),
              __builtin_types_compatible_p(char, signed char), __builtin_types_compatible_p(int[3], int[4]),
              __builtin_types_compatible_p(unsigned, unsigned int), __builtin_types_compatible_p(volatile double, double) };
  char buf[__builtin_types_compatible_p(int, int) + 1];
  for (unsigned i = 0; i < sizeof r / sizeof r[0]; i++) printf("%d", r[i]);
  printf(" %zu\n", sizeof buf);
  return 0;
}
