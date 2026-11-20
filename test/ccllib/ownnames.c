/* ownnames.c (1.6.2): a name that the program declares is the program's, beside a ccllib module's macro of the name --
   a function of the file and of a header of its own, a function named as a macro that takes an argument unread, a
   parameter, a local function pointer, a block's local that hides the macro to the block's end; a name that the program
   does not declare stays the module's macro */
#include <stdio.h>
#include <functional.pl>
#include <algorithm.pl>
#include "ownhdr.h"
static unsigned hash(const char *s) { unsigned h = 0; while (*s) h = h * 31 + (unsigned char)*s++; return h; }
static int less(const char *a, const char *b) { return a[0] < b[0]; }
static int count_if(int a, int b, int c) { return a + b + c; }
static int sub(int a, int b) { return a - b; }
static int apply(int (*plus)(int, int), int x) { return plus(x, 1); }
int main(void) {
    const char *x = "abc";
    const char *p = "b", *q = "a";
    printf("%u %d\n", hash(x), less(p, q));
    printf("%d %d\n", greater(7, 3), count_if(1, 2, 3));
    printf("%d\n", apply(sub, 5));
    int (*minus)(int, int) = sub;
    printf("%d\n", minus(4, 9));
    { int (*modulus)(int, int) = sub; printf("%d\n", modulus(3, 1)); }
    printf("%d\n", modulus(7, 4));
    printf("%d %d %d\n", equal_to(2, 2), multiplies(6, 7), logical_not(0));
    return 0;
}
