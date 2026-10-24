/* GCC's packed attribute on an enum: the smallest integer type that holds its enumerators, unsigned where none is negative,
   and _Generic takes a packed member's type as the plain type it is */
#include <stdio.h>
enum __attribute__((packed)) E1 { A1 = 0, B1 = 70000 };
enum __attribute__((packed)) E2 { A2 = 0, B2 = 200 };
enum __attribute__((packed)) E3 { A3 = -1, B3 = 100 };
enum __attribute__((packed)) E4 { A4 = 0, B4 = 3000000000u };
struct __attribute__((packed)) P { char c; int i; };
int main(void) {
  struct P p = { 1, 2 };
  printf("%zu %zu %zu %zu\n", sizeof(enum E1), sizeof(enum E2), sizeof(enum E3), sizeof(enum E4));
  printf("%d %d %d\n", (enum E1)B1 > -1, (enum E2)B2 > -1, (enum E3)A3 < 0);
  printf("%d %d\n", _Generic(&p.i, int *: 1, default: 0), _Generic(p.i, int: 1, default: 0));
  return 0;
}
