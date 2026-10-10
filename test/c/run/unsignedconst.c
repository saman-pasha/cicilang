/* UNSIGNED CONSTANT ARITHMETIC (0.128): `~0u / 3' folded to 0 -- the complement was -1 -- and `-1 < 0u' held; an
   operation whose common type is unsigned converts its operands to it and wraps its result, as C has it. */
#include <stdio.h>
#include <limits.h>
_Static_assert(~0UL / 3 == 0x5555555555555555UL, "ul");
_Static_assert(~0u / 3 == 0x55555555u, "u");
_Static_assert(0u - 1 == UINT_MAX, "wrap");
_Static_assert(!(-1 < 0u), "convert");
_Static_assert(-1 > 0u, "convert2");
_Static_assert((0u - 1) >> 28 == 15, "shift");
_Static_assert(-1L < 0, "signed");
_Static_assert(~0 == -1, "int");
_Static_assert((unsigned char)~0 == 255, "uchar");
_Static_assert(-1u == 4294967295u, "neg");
#if ~0u == 0xFFFFFFFFFFFFFFFF
enum { PP = 64 };     /* #if computes in uintmax_t */
#else
enum { PP = 32 };
#endif
enum { A = ~0u / 5, B = (int)(0u - 3), C = -1 < 0u };
unsigned long g1 = ~0UL / 3;
unsigned int g2 = ~0u / 3;
unsigned long long g3 = -1ULL % 1000;
unsigned g4 = (0u - 2) / 2;
int g5 = (-7) / 2;
unsigned g6[(~0u >> 30)];
int main(void) {
  printf("%lx %x %llu %u %d %zu\n", g1, g2, g3, g4, g5, sizeof g6 / sizeof g6[0]);
  printf("%d %d %d %d\n", PP, A, B, C);
  return 0;
}
