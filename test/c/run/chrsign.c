/* A plain character literal's value past 127 is a char's, converted to int (C 6.4.4.4/10): signed on x86-64 Linux,
   unsigned on aarch64 Linux; in an expression, a case label and #if alike (0.196) */
#include <stdio.h>
int main(void) {
    char c = '\xff'; char d = (char) 233;
    printf("%d %d %d %d %d %d\n", '\xE9', '\377', '\x80', c == '\xff', d == '\xE9', (int) sizeof('\xE9'));
    switch (c) { case '\xff': puts("ff"); break; default: puts("other"); }
#if '\xff' < 0
    puts("pp signed");
#else
    puts("pp unsigned");
#endif
    return 0;
}
