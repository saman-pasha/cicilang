#include <stdio.h>
/* an integer literal is the first type that holds its value (C 6.4.4.1/5): a decimal one past INT_MAX a long, a hex,
   octal or binary one past INT_MAX that an unsigned int holds an unsigned int; a switch over a long or an unsigned long
   long compares its cases at that width */
#define T(x) _Generic((x), int: "int", unsigned: "unsigned", long: "long", unsigned long: "unsigned long", long long: "long long", unsigned long long: "unsigned long long", default: "other")
int main(void) {
  printf("%s %s %s %s\n", T(2147483647), T(2147483648), T(4294967295), T(4294967296));
  printf("%s %s %s %s\n", T(0x7FFFFFFF), T(0x80000000), T(0xFFFFFFFF), T(0x100000000));
  printf("%s %s %s\n", T(017777777777), T(020000000000), T(037777777777));
  printf("%s %s %s\n", T(0b1111111111111111111111111111111), T(0b10000000000000000000000000000000), T(0b100000000000000000000000000000000));
  printf("%s %s %s %s\n", T(4294967295u), T(4294967296u), T(0x80000000l), T(9223372036854775807));
  printf("%s %s\n", T(0xFFFFFFFFFFFFFFFF), T(0x8000000000000000l));
  printf("%s %s\n", T(0x7FFFFFFFFFFFFFFFll), T(0xFFFFFFFFFFFFFFFFll));
  printf("%zu %zu %zu %zu\n", sizeof 2147483648, sizeof 0x80000000, sizeof 4294967296u, sizeof 0xFFFFFFFF);
  printf("%d %u %ld %lu\n", ~0x7FFFFFFF, ~0x80000000, ~2147483648, ~4294967296u);
  printf("%d %d %d\n", 0x80000000 > -1, 2147483648 > -1, 0xFFFFFFFF == -1);
  enum { E1 = 0x80000000 > 0 };
  printf("%d %u %ld\n", E1, 0xFFFFFFFF >> 4, -2147483648);
#if 0x80000000 > -1
  puts("pp hex signed");
#endif
#if 0x80000000u > -1
  puts("pp u wrong");
#else
  puts("pp u unsigned");
#endif
  long x = 0x100000001L;
  switch (x) { case 1: puts("one"); break; case 0x100000001L: puts("big"); break; default: puts("none"); }
  unsigned long long y = 18446744073709551615ULL;
  switch (y) { case 18446744073709551615ULL: puts("max"); break; case 0xFFFFFFFF: puts("low"); break; default: puts("no"); }
  unsigned char c = 200;
  switch (c) { case 200: puts("c200"); break; default: puts("cno"); }
  return 0;
}
