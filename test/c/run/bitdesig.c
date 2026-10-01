// A designated list over bitfields with a hole between two designators: the hole is the member's zero (C11 6.7.9/19).
#include <stdio.h>
struct F { unsigned a : 1, b : 1, c : 1; int d; };
struct F g = {.a = 1, .c = 1};
struct F h = {.c = 1, .d = 7};
int main(void) { printf("%u %u %u %d | %u %u %u %d\n", g.a, g.b, g.c, g.d, h.a, h.b, h.c, h.d); return 0; }
