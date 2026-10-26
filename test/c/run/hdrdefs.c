#define _DEFAULT_SOURCE
#include <stdio.h>
#include <byteswap.h>
#include <endian.h>
#include "hdrdefs.h"
/* the definitions a header makes are the unit's (C17 6.9/5, 6.9.2/2): its static and static inline functions, a static
   object, an external definition and an object, C99's inline definition made external by this unit's declaration
   (6.7.4/7), and the C library's static inline functions behind bswap_32 and htobe32; 0.211 emitted none of them, and
   the link named each one */
extern inline int hd_sq(int x);
int (*fp)(int) = hd_twice;
int main(void) {
  hd_count();
  printf("%d %d %d %d %d\n", hd_twice(21), hd_ext(10), hd_sq(9), hd_table[2], hd_global);
  printf("%x %x %llx\n", bswap_32(0x11223344u), (unsigned) bswap_16(0xabcd), (unsigned long long) bswap_64(0x0102030405060708ull));
  printf("%x %d %d\n", (unsigned) htobe32(0x01020304u), fp(5), hd_calls);
  return 0;
}
