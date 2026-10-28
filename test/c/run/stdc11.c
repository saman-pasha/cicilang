/* C11 (0.221): its own __STDC_VERSION__, and names of C11's Annex D that C23 refuses -- the euro sign in a macro's name, a
   middle dot first -- beside a combining acute after a letter, which C99 refuses */
#include <stdio.h>
#define PRICE€ 5
int ·count = 2;
int x́ = 3;
int main(void) { printf("%ld %d %d %d\n", (long)__STDC_VERSION__, PRICE€, ·count, x́); return 0; }
