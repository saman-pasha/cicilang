/* C99 (0.221): its own __STDC_VERSION__, `typeof' and `bool' names, no keywords of C99's ISO mode, and a name of C99's Annex D --
   where -std=c99 was read as C23, its level 99 compared as a number above 23 */
#include <stdio.h>
int typeof = 3;
int bool = 2;
int café = 7;
int main(void) { printf("%ld %d %d %d\n", (long)__STDC_VERSION__, typeof, bool, café); return 0; }
