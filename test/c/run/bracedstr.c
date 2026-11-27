/* A string literal in braces for an array of a character type is the literal (1.6.39; C17 6.7.9/14): a bound from it, a bound
   it fits, a local, beside an array of pointers and a two-dimensional array, whose braces hold their items */
#include <stdio.h>
static const char b[] = { "braced" };
char c[10] = { "ten" };
const char *ps[] = { "one" };
char m[2][4] = { "ab", "cd" };
int main(void) { const char d[] = { "local" }; printf("%s %s %s %s %s %d %d %d\n", b, c, d, ps[0], m[1], (int)sizeof b, (int)sizeof d, (int)sizeof ps); return 0; }
