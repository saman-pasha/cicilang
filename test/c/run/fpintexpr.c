/* AN INTEGER OPERATION IN A FLOATING GLOBAL'S INITIALIZER IS AN INTEGER OPERATION (0.154): done in its own type, exactly, and
   converted once where a floating operand meets it (C 6.3.1.8). The fold did it in doubles, in cocolog's 61-bit integers:
   `0x0FFFFFFFFFFFFFFFLL + 0x0FFFFFFFFFFFFFFFLL' was -2, an unsigned negation stayed negative, and a 128-bit sum was
   rounded at each step */
#include <stdio.h>

typedef __int128 i128;
double a1 = ((i128) 1 << 64) + 2048 + 1;                       /* the exact sum, rounded once: up */
double a2 = 0x0FFFFFFFFFFFFFFFLL + 0x0FFFFFFFFFFFFFFFLL;       /* 2^61 - 2, past cocolog's integers */
double a3 = 0x7FFFFFFFFFFFFFFFLL / 3, a4 = (0x0FFFFFFFFFFFFFFFLL * 8) + 0.5;
double a5 = -1u, a6 = 0u - 1, a7 = (unsigned char) 300 + 0.5, a8 = (unsigned long long) -1 / 2.0;
double a9 = (signed char) 200 * 2, a10 = 7 / 2 + 0.25, a11 = -7 / 2, a12 = 7 % 3 * 1.5, a13 = (1ULL << 63) + (1ULL << 63);
float f1 = ((i128) 1 << 100) + ((i128) 1 << 76) + 1, f2 = 16777217, f3 = (float) 16777217 + 0, f4 = 0x7FFFFFFFFFFFFFFFLL - 1;
long double l1 = ((i128) 1 << 64) + 2048 + 1, l2 = (((i128) 1 << 64) + 3) + 0.5L, l3 = 0x0FFFFFFFFFFFFFFFLL + 0x0FFFFFFFFFFFFFFFLL;
long double l4 = (unsigned __int128) -1, l5 = -1u + 0.5L, l6 = (((i128) 1 << 64) + 1) * 3;

int main(void) {
    printf("%a %a %a %a\n", a1, a2, a3, a4);
    printf("%a %a %a %a\n", a5, a6, a7, a8);
    printf("%a %a %a %a %a\n", a9, a10, a11, a12, a13);
    printf("%a %a %a %a\n", (double) f1, (double) f2, (double) f3, (double) f4);
    printf("%La %La %La\n", l1, l2, l3);
    printf("%La %La %La\n", l4, l5, l6);
    return 0;
}
