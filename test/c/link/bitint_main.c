/* bitint_main.c -- built by cicilang over bitint_helper.c built by clang (1.6.57): _BitInt values cross the calls both ways,
   each printed by its 32-bit pieces, beside clang's own build of the two */
#include <stdio.h>
#include "bitint.h"
B100 m100(B100 v, int k) { return v * k; }
B65 m65(long a, long b, long c, long d, long e, B65 v) { return v + a + b + c + d + e; }
#if defined(__x86_64__)
U200 m200(U200 v, int k) { return v + (unsigned) k; }
#endif
static void show(const char *name, unsigned _BitInt(256) v) {
  printf("%s", name);
  for (int i = 7; i >= 0; i--) printf(" %08x", (unsigned) (v >> (32 * i)));
  printf("\n");
}
int main(void) {
  B100 big = ((B100) 0x123456789abcdefLL << 36) + 0x55aa;
  show("h48", (unsigned _BitInt(256)) h48(-140737488355000LL / 7, 7));
  show("h63", h63(0x7ffffffffffffff1ULL));
  show("h65", (unsigned _BitInt(256)) h65(((B65) 1 << 63) + 5, -9));
  show("h100", (unsigned _BitInt(256)) h100(1, 2, 3, 4, 5, big, 6));
  show("h127", h127(3, ((U127) 1 << 120) + 0xabcdef));
  show("h128", (unsigned _BitInt(256)) h128(10, 20, 30, 40, 50, -((B128) 1 << 100) + 999));
  show("hcall", (unsigned _BitInt(256)) hcall(m100, -big));
  show("r48", (unsigned _BitInt(256)) r48(-123456789012L));
  show("r65", (unsigned _BitInt(256)) r65(-5));
  show("hva", (unsigned _BitInt(256)) hva(4, (B48) -5, big, (B48) 7, big * 2, (B48) 100000000000, big * 3, (B48) 9, -big));
#if defined(__x86_64__)
  show("h129", (unsigned _BitInt(256)) h129(((B129) 1 << 127) + 77, 2));
  show("h200", h200(4, ((U200) 1 << 190) + 0x1234, ((U200) 1 << 9) + 3));
  show("h256", (unsigned _BitInt(256)) h256(((B256) 7 << 250) + 1, 1, 2, 3, 4, 5, ((B256) 3 << 128) - 11));
  show("r200", r200(-1L));
  show("hvb", (unsigned _BitInt(256)) hvb(3, ((B129) 5 << 100) + 1, (U63) 11, -((B129) 3 << 100), (U63) 12, ((B129) 1 << 127) - 1, (U63) 13));
#endif
  return 0;
}
